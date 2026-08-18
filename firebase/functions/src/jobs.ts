import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { BookingData } from './types';

/** Allowed forward transitions for the on-site flow (plan §3.2). */
const TRANSITIONS: Record<
  string,
  { from: string; to: string; timestampField: string }
> = {
  start_trip: { from: 'accepted', to: 'en_route', timestampField: 'enRouteAt' },
  start_service: {
    from: 'en_route',
    to: 'in_progress',
    timestampField: 'startedServiceAt',
  },
  complete: {
    from: 'in_progress',
    to: 'completed',
    timestampField: 'completedAt',
  },
};

/** Customer-facing push copy per on-site transition. */
const CUSTOMER_NOTIFICATIONS: Record<string, { title: string; body: string }> = {
  start_trip: {
    title: 'Your technician is on the way',
    body: 'Track their live location in the booking details.',
  },
  start_service: {
    title: 'Technician on site',
    body: 'They have started the job at your location.',
  },
  complete: {
    title: 'Job completed',
    body: 'Thanks for using MEP Connect. You can rate your technician now.',
  },
};

/**
 * Drives the on-site flow: start_trip → start_service → complete.
 * Only the assigned technician may advance the job, and only one step
 * at a time (transaction-enforced state machine).
 */
export const updateJobStatus = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const bookingId = request.data?.bookingId as string | undefined;
    const action = request.data?.action as string | undefined;
    if (!bookingId || !action || !(action in TRANSITIONS)) {
      throw new HttpsError('invalid-argument', 'Invalid booking or action.');
    }

    const db = getFirestore();
    const ref = db.doc(`bookings/${bookingId}`);
    const transition = TRANSITIONS[action];

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Booking not found.');
      }
      const booking = snap.data() as BookingData;
      if (booking.technicianId !== request.auth!.uid) {
        throw new HttpsError(
          'permission-denied',
          'You are not assigned to this job.',
        );
      }
      if (booking.status !== transition.from) {
        throw new HttpsError(
          'failed-precondition',
          'The job is no longer in that state.',
        );
      }
      const now = FieldValue.serverTimestamp();
      tx.update(ref, {
        status: transition.to,
        [transition.timestampField]: now,
        updatedAt: now,
      });
    });

    await notifyCustomer(bookingId, action);
    return { bookingId, status: transition.to };
  },
);

/**
 * Cancels a job. Either participant may cancel:
 * - technician: while accepted/en_route (counts against reliability stats)
 * - customer: while pending/matching (client path) or accepted/en_route
 */
export const cancelJob = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const bookingId = request.data?.bookingId as string | undefined;
    if (!bookingId || typeof bookingId !== 'string') {
      throw new HttpsError('invalid-argument', 'bookingId required.');
    }

    const db = getFirestore();
    const ref = db.doc(`bookings/${bookingId}`);

    const outcome = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Booking not found.');
      }
      const booking = snap.data() as BookingData;
      const uid = request.auth!.uid;
      const isCustomer = booking.customerId === uid;
      const isTechnician = booking.technicianId === uid;
      if (!isCustomer && !isTechnician) {
        throw new HttpsError(
          'permission-denied',
          'You are not part of this booking.',
        );
      }

      const status = booking.status;
      const cancellable = isTechnician
        ? status === 'accepted' || status === 'en_route'
        : status === 'pending' ||
          status === 'matching' ||
          status === 'accepted' ||
          status === 'en_route';
      if (!cancellable) {
        throw new HttpsError(
          'failed-precondition',
          'This booking can no longer be cancelled.',
        );
      }

      const now = FieldValue.serverTimestamp();
      tx.update(ref, {
        status: 'cancelled',
        cancellationReason: isTechnician
          ? 'cancelled_by_technician'
          : 'cancelled_by_customer',
        cancelledAt: now,
        updatedAt: now,
      });

      // Technician-initiated cancellations count against reliability.
      if (isTechnician) {
        tx.update(db.doc(`technicians/${uid}`), {
          cancelledJobs: FieldValue.increment(1),
          updatedAt: now,
        });
      }

      return {
        isCustomer,
        customerId: booking.customerId,
        technicianId: booking.technicianId ?? null,
      };
    });

    // Notify the other participant.
    const recipient = outcome.isCustomer
      ? outcome.technicianId
      : outcome.customerId;
    if (recipient) {
      await sendToUser(
        recipient,
        'Booking cancelled',
        'Your booking has been cancelled.',
        { type: 'booking_cancelled', bookingId },
      );
    }
    return { bookingId, status: 'cancelled' };
  },
);

async function notifyCustomer(
  bookingId: string,
  action: string,
): Promise<void> {
  const db = getFirestore();
  const bookingSnap = await db.doc(`bookings/${bookingId}`).get();
  if (!bookingSnap.exists) return;
  const booking = bookingSnap.data() as BookingData;
  const copy = CUSTOMER_NOTIFICATIONS[action];
  if (!copy) return;
  await sendToUser(booking.customerId, copy.title, copy.body, {
    type: 'job_status',
    bookingId,
  });
}

async function sendToUser(
  uid: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const db = getFirestore();
  const userSnap = await db.doc(`users/${uid}`).get();
  const token = userSnap.data()?.fcmToken as string | undefined;
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data,
      android: { priority: 'high' },
    });
  } catch (_) {
    // Best-effort push; Firestore streams cover the UI.
  }
}
