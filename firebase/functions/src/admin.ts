import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { BookingData } from './types';

/**
 * Admin-only helpers (plan §4). Every callable verifies
 * `users/{uid}.role == 'admin'` server-side — rules alone cannot gate
 * these because technicians/{uid}.kycStatus is frozen for self-updates
 * and refunds touch multiple documents atomically.
 */

async function requireAdmin(request: { auth?: { uid?: string } | null }) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }
  const db = getFirestore();
  const userSnap = await db.doc(`users/${uid}`).get();
  if (!userSnap.exists || userSnap.data()?.role !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin access required.');
  }
  return uid;
}

/** Verifies (or rejects) a technician's KYC. */
export const approveTechnicianKyc = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    await requireAdmin(request);
    const target = request.data?.uid as string | undefined;
    const status = request.data?.status as string | undefined;
    if (!target || typeof target !== 'string') {
      throw new HttpsError('invalid-argument', 'technician uid required.');
    }
    if (status !== 'approved' && status !== 'rejected') {
      throw new HttpsError('invalid-argument', 'status must be approved/rejected.');
    }

    const db = getFirestore();
    const ref = db.doc(`technicians/${target}`);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Technician not found.');
    }
    await ref.update({
      kycStatus: status,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { uid: target, kycStatus: status };
  },
);

/**
 * Resolves a complaint (plan §4.2). Optionally issues a refund on paid
 * jobs: booking → `refunded`, payment → `refunded`, technician earnings
 * reversed — all in one transaction.
 */
export const resolveComplaint = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    await requireAdmin(request);
    const bookingId = request.data?.bookingId as string | undefined;
    const resolution = request.data?.resolution as string | undefined;
    const refund = request.data?.refund === true;
    if (!bookingId || typeof bookingId !== 'string') {
      throw new HttpsError('invalid-argument', 'bookingId required.');
    }
    if (!resolution || typeof resolution !== 'string') {
      throw new HttpsError('invalid-argument', 'resolution required.');
    }

    const db = getFirestore();
    const bookingRef = db.doc(`bookings/${bookingId}`);
    const complaintRef = db.doc(`complaints/${bookingId}`);
    const paymentRef = db.doc(`payments/${bookingId}`);

    await db.runTransaction(async (tx) => {
      const bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) {
        throw new HttpsError('not-found', 'Booking not found.');
      }
      const booking = bookingSnap.data() as BookingData;
      if (booking.complaint?.status !== 'submitted') {
        throw new HttpsError('failed-precondition', 'No open complaint.');
      }

      const now = FieldValue.serverTimestamp();
      tx.update(complaintRef, {
        status: 'resolved',
        resolution: resolution.slice(0, 1000),
        resolvedAt: now,
        updatedAt: now,
      });
      tx.update(bookingRef, {
        complaint: {
          ...booking.complaint,
          status: 'resolved',
          resolution: resolution.slice(0, 1000),
        },
        updatedAt: now,
      });

      if (refund && booking.payment?.status === 'paid') {
        const paymentSnap = await tx.get(paymentRef);
        const payment = paymentSnap.exists ? paymentSnap.data()! : null;
        const amount = payment?.amount as number | undefined;
        if (typeof amount === 'number' && amount > 0 && booking.technicianId) {
          const paidMonth =
            payment?.paidAt instanceof Date
              ? payment.paidAt.toISOString().slice(0, 7)
              : new Date().toISOString().slice(0, 7);
          tx.update(bookingRef, { status: 'refunded' });
          tx.update(paymentRef, { status: 'refunded', updatedAt: now });
          tx.update(db.doc(`technicians/${booking.technicianId}`), {
            totalEarned: FieldValue.increment(-amount),
            balance: FieldValue.increment(-amount),
            [`earningsByMonth.${paidMonth}`]: FieldValue.increment(-amount),
            updatedAt: now,
          });
        }
      }
    });

    return { bookingId, status: 'resolved', refunded: refund };
  },
);

/**
 * Processes a technician payout (plan §4.4): deducts the amount from
 * the withdrawable balance and records a `payout` payment entry.
 */
export const processPayout = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    await requireAdmin(request);
    const technicianId = request.data?.technicianId as string | undefined;
    const amount = request.data?.amount as number | undefined;
    if (!technicianId || typeof technicianId !== 'string') {
      throw new HttpsError('invalid-argument', 'technicianId required.');
    }
    if (typeof amount !== 'number' || !Number.isInteger(amount) || amount <= 0) {
      throw new HttpsError('invalid-argument', 'amount must be a positive integer.');
    }

    const db = getFirestore();
    const techRef = db.doc(`technicians/${technicianId}`);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(techRef);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Technician not found.');
      }
      const balance = (snap.data()?.balance as number) || 0;
      if (balance < amount) {
        throw new HttpsError('failed-precondition', 'Insufficient balance.');
      }
      const now = FieldValue.serverTimestamp();
      tx.update(techRef, {
        balance: FieldValue.increment(-amount),
        totalWithdrawn: FieldValue.increment(amount),
        updatedAt: now,
      });
      tx.set(
        db.doc(`payments/PO-${technicianId.slice(-6)}-${Date.now().toString(36).toUpperCase()}`),
        {
          type: 'payout',
          technicianId,
          amount,
          status: 'succeeded',
          paidAt: now,
          createdAt: now,
        },
      );
    });
    return { technicianId, amount, status: 'succeeded' };
  },
);
