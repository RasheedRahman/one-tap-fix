import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { BookingData } from './types';

/** Complaint reasons (plan §2.8). */
const REASONS = [
  'job_not_done_properly',
  'technician_no_show',
  'overcharging',
  'poor_behaviour',
  'other',
];

/** Reasons that auto-trigger a refund (plan §2.8 "auto-refund"). */
const AUTO_REFUND_REASONS = ['job_not_done_properly'];

/**
 * Files a complaint on a completed booking (plan §2.8). The customer
 * uploads photos to storage first, then this callable:
 * - creates `complaints/{bookingId}` (one per booking)
 * - records `booking.complaint{reason, status}`
 * - auto-refunds paid jobs whose reason is in AUTO_REFUND_REASONS:
 *   booking → `refunded`, payment → `refunded`, technician earnings
 *   are reversed (no gateway money moves offline — recorded as a
 *   credit/refund ledger entry).
 */
export const submitComplaint = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const bookingId = request.data?.bookingId as string | undefined;
    const reason = request.data?.reason as string | undefined;
    const description = request.data?.description as string | undefined;
    const photoUrls = request.data?.photoUrls as string[] | undefined;
    if (!bookingId || typeof bookingId !== 'string') {
      throw new HttpsError('invalid-argument', 'bookingId required.');
    }
    if (!reason || !REASONS.includes(reason)) {
      throw new HttpsError('invalid-argument', 'Invalid complaint reason.');
    }

    const db = getFirestore();
    const uid = request.auth.uid;
    const bookingRef = db.doc(`bookings/${bookingId}`);
    const complaintRef = db.doc(`complaints/${bookingId}`);
    const paymentRef = db.doc(`payments/${bookingId}`);

    const result = await db.runTransaction(async (tx) => {
      const bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) {
        throw new HttpsError('not-found', 'Booking not found.');
      }
      const booking = bookingSnap.data() as BookingData;
      if (booking.customerId !== uid) {
        throw new HttpsError(
          'permission-denied',
          'Only the customer can complain.',
        );
      }
      if (booking.status !== 'completed') {
        throw new HttpsError(
          'failed-precondition',
          'Complaints open only after the job is completed.',
        );
      }
      if (booking.complaint?.status === 'submitted') {
        throw new HttpsError(
          'failed-precondition',
          'A complaint already exists for this booking.',
        );
      }

      const now = FieldValue.serverTimestamp();
      tx.set(complaintRef, {
        bookingId,
        customerId: uid,
        technicianId: booking.technicianId ?? null,
        reason,
        description: String(description ?? '').slice(0, 1000),
        photoUrls: Array.isArray(photoUrls) ? photoUrls.slice(0, 5) : [],
        status: 'submitted',
        createdAt: now,
        updatedAt: now,
      });
      tx.update(bookingRef, {
        complaint: { reason, status: 'submitted' },
        updatedAt: now,
      });

      const autoRefund =
        AUTO_REFUND_REASONS.includes(reason) &&
        booking.payment?.status === 'paid' &&
        !!booking.technicianId;
      if (autoRefund) {
        const paymentSnap = await tx.get(paymentRef);
        const payment = paymentSnap.exists ? paymentSnap.data()! : null;
        const amount = payment?.amount as number | undefined;
        if (typeof amount === 'number' && amount > 0) {
          const paidMonth =
            payment?.paidAt instanceof Date
              ? payment.paidAt.toISOString().slice(0, 7)
              : new Date().toISOString().slice(0, 7);

          tx.update(bookingRef, {
            status: 'refunded',
            updatedAt: now,
          });
          tx.update(paymentRef, {
            status: 'refunded',
            updatedAt: now,
          });
          tx.update(db.doc(`technicians/${booking.technicianId}`), {
            totalEarned: FieldValue.increment(-amount),
            balance: FieldValue.increment(-amount),
            [`earningsByMonth.${paidMonth}`]: FieldValue.increment(-amount),
            updatedAt: now,
          });
        }
      }

      return { autoRefund, technicianId: booking.technicianId ?? null };
    });

    if (result.technicianId) {
      await sendToUser(
        result.technicianId,
        result.autoRefund ? 'Refund issued' : 'New complaint',
        result.autoRefund
          ? 'A refund was issued for a completed job.'
          : 'A customer raised an issue on a completed job.',
        { type: 'complaint_submitted', bookingId },
      );
    }
    return {
      complaintId: bookingId,
      status: 'submitted',
      refunded: result.autoRefund,
    };
  },
);

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
    // Best-effort push; booking streams cover the UI.
  }
}
