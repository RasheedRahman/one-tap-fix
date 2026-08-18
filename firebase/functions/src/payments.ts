import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { BookingData } from './types';

const PAYMENT_METHODS = ['upi', 'cash'];

/**
 * Starts a payment for a booking (plan §2.6). Only the customer can pay,
 * and only while the job is in progress or completed but unpaid. Creates
 * `payments/{bookingId}` with the amount frozen from the booking's pricing
 * snapshot. Idempotent: an existing `initiated` payment is returned as-is.
 */
export const initiatePayment = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const bookingId = request.data?.bookingId as string | undefined;
    const method = request.data?.method as string | undefined;
    if (!bookingId || typeof bookingId !== 'string') {
      throw new HttpsError('invalid-argument', 'bookingId required.');
    }
    if (!method || !PAYMENT_METHODS.includes(method)) {
      throw new HttpsError(
        'invalid-argument',
        'method must be one of: ' + PAYMENT_METHODS.join(', '),
      );
    }

    const db = getFirestore();
    const uid = request.auth.uid;
    const bookingRef = db.doc(`bookings/${bookingId}`);
    const paymentRef = db.doc(`payments/${bookingId}`);

    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Booking not found.');
    }
    const booking = bookingSnap.data() as BookingData;
    if (booking.customerId !== uid) {
      throw new HttpsError('permission-denied', 'Only the customer pays.');
    }
    if (booking.status !== 'in_progress' && booking.status !== 'completed') {
      throw new HttpsError(
        'failed-precondition',
        'Payment opens only during or after the service.',
      );
    }
    if (booking.payment?.status === 'paid') {
      throw new HttpsError('failed-precondition', 'Already paid.');
    }

    // Amount is recomputed from the immutable pricing snapshot
    // (the client's estimatedTotal is never trusted).
    const p = booking.pricing;
    const baseTotal = (p?.minCharge ?? 0) + (p?.serviceCharge ?? 0);
    const amount =
      baseTotal + Math.round((baseTotal * (p?.gstPercent ?? 0)) / 100);
    if (amount <= 0) {
      throw new HttpsError('failed-precondition', 'Invalid amount.');
    }

    // Idempotent: reuse an initiated payment for this booking.
    const existing = await paymentRef.get();
    if (existing.exists && existing.data()?.status === 'initiated') {
      return { paymentId: bookingId, amount, method: existing.data()?.method };
    }

    const now = FieldValue.serverTimestamp();
    await paymentRef.set({
      type: 'payment',
      bookingId,
      customerId: uid,
      technicianId: booking.technicianId ?? null,
      method,
      amount,
      status: 'initiated',
      createdAt: now,
      updatedAt: now,
    });
    return { paymentId: bookingId, amount, method };
  },
);

/**
 * Records a successful payment (plan §2.6). The customer confirms after
 * the UPI intent completes or cash is collected. Transactionally:
 * - payment doc → `succeeded` (immutable amount/method)
 * - booking gains its `payment` map (paid at the snapshot total)
 * - technician earnings (`totalEarned`, `balance`, `earningsByMonth`)
 *
 * NOTE: with a live gateway this would be called from a webhook after
 * server-side verification; the callable is the offline-safe path.
 */
export const confirmPayment = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const paymentId = request.data?.paymentId as string | undefined;
    if (!paymentId || typeof paymentId !== 'string') {
      throw new HttpsError('invalid-argument', 'paymentId required.');
    }

    const db = getFirestore();
    const paymentRef = db.doc(`payments/${paymentId}`);
    const uid = request.auth.uid;

    const outcome = await db.runTransaction(async (tx) => {
      const paymentSnap = await tx.get(paymentRef);
      if (!paymentSnap.exists) {
        throw new HttpsError('not-found', 'Payment not found.');
      }
      const payment = paymentSnap.data()!;
      if (payment.customerId !== uid) {
        throw new HttpsError(
          'permission-denied',
          'Only the customer can confirm.',
        );
      }
      if (payment.status === 'succeeded') {
        throw new HttpsError('failed-precondition', 'Already paid.');
      }
      if (payment.status !== 'initiated') {
        throw new HttpsError('failed-precondition', 'Payment not payable.');
      }
      const method = payment.method as string;
      const amount = payment.amount as number;
      if (!PAYMENT_METHODS.includes(method) || typeof amount !== 'number') {
        throw new HttpsError('internal', 'Corrupt payment record.');
      }

      const now = FieldValue.serverTimestamp();
      const transactionId = `TXN-${paymentId.slice(-6).toUpperCase()}-${Date.now().toString(36).toUpperCase()}`;
      const month = new Date().toISOString().slice(0, 7); // YYYY-MM

      tx.update(paymentRef, {
        status: 'succeeded',
        transactionId,
        paidAt: now,
        updatedAt: now,
      });
      tx.update(db.doc(`bookings/${paymentId}`), {
        payment: {
          method,
          status: 'paid',
          transactionId,
          paidAt: now,
        },
        updatedAt: now,
      });
      if (payment.technicianId) {
        tx.update(db.doc(`technicians/${payment.technicianId}`), {
          totalEarned: FieldValue.increment(amount),
          balance: FieldValue.increment(amount),
          [`earningsByMonth.${month}`]: FieldValue.increment(amount),
          updatedAt: now,
        });
      }
      return {
        technicianId: payment.technicianId as string | null,
        amount,
      };
    });

    if (outcome.technicianId) {
      await sendToUser(
        outcome.technicianId,
        'Payment received',
        `₹${outcome.amount} received for a job.`,
        { type: 'payment_received', bookingId: paymentId },
      );
    }
    return { paymentId, status: 'succeeded' };
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
    // Best-effort push; payment streams cover the UI.
  }
}
