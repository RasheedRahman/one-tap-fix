import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

/**
 * Subscription & commission (plan §3.7). Technicians subscribe monthly
 * (₹499, 10% commission) or yearly (₹4999, 5% commission); the yearly
 * plan is the discounted commitment. Commission rates are returned to
 * the client for display but enforced by the admin settlement logic.
 */
export const SUBSCRIPTION_PLANS = {
  monthly: { amount: 499, commissionPercent: 10, months: 1 },
  yearly: { amount: 4999, commissionPercent: 5, months: 12 },
} as const;

export type SubscriptionPlan = keyof typeof SUBSCRIPTION_PLANS;

/**
 * Activates a technician subscription (plan §3.7). Creates a
 * `subscription` payment ledger entry and updates
 * `technicians/{uid}.subscription`. Offline-settled like job payments —
 * a live gateway (Razorpay) would call this after webhook verification.
 */
export const subscribeTechnician = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const plan = request.data?.plan as SubscriptionPlan | undefined;
    if (!plan || !(plan in SUBSCRIPTION_PLANS)) {
      throw new HttpsError(
        'invalid-argument',
        'plan must be monthly or yearly.',
      );
    }

    const db = getFirestore();
    const uid = request.auth.uid;
    const techRef = db.doc(`technicians/${uid}`);
    const techSnap = await techRef.get();
    if (!techSnap.exists) {
      throw new HttpsError('not-found', 'Technician profile not found.');
    }

    const config = SUBSCRIPTION_PLANS[plan];
    const now = new Date();
    const expiry = new Date(now);
    expiry.setMonth(expiry.getMonth() + config.months);

    const existing = techSnap.data()?.subscription as
      | { status?: string; expiry?: Date | string }
      | undefined;
    if (existing?.status === 'active' && existing.expiry) {
      const exp =
        existing.expiry instanceof Date
          ? existing.expiry
          : new Date(existing.expiry);
      if (exp > now) {
        // Renewal extends from the current expiry date.
        expiry.setTime(exp.getTime());
        expiry.setMonth(expiry.getMonth() + config.months);
      }
    }

    await db.runTransaction(async (tx) => {
      const nowTs = FieldValue.serverTimestamp();
      tx.update(techRef, {
        subscription: {
          plan,
          status: 'active',
          startedAt: now,
          expiresAt: expiry,
          commissionPercent: config.commissionPercent,
        },
        updatedAt: nowTs,
      });
      tx.set(
        db.doc(
          `payments/SUB-${uid.slice(-6)}-${Date.now().toString(36).toUpperCase()}`,
        ),
        {
          type: 'subscription',
          technicianId: uid,
          amount: config.amount,
          status: 'succeeded',
          plan,
          paidAt: nowTs,
          createdAt: nowTs,
        },
      );
    });

    return {
      plan,
      amount: config.amount,
      commissionPercent: config.commissionPercent,
      expiresAt: expiry.toISOString(),
    };
  },
);

/** Admin-only: cancels a technician's active subscription. */
export const cancelSubscription = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    const adminUid = request.auth?.uid;
    if (!adminUid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const db = getFirestore();
    const adminSnap = await db.doc(`users/${adminUid}`).get();
    if (!adminSnap.exists || adminSnap.data()?.role !== 'admin') {
      throw new HttpsError('permission-denied', 'Admin access required.');
    }

    const technicianId = request.data?.technicianId as string | undefined;
    if (!technicianId || typeof technicianId !== 'string') {
      throw new HttpsError('invalid-argument', 'technicianId required.');
    }

    const ref = db.doc(`technicians/${technicianId}`);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Technician not found.');
    }
    const subscription = snap.data()?.subscription as
      | Record<string, unknown>
      | undefined;
    if (subscription?.status !== 'active') {
      throw new HttpsError('failed-precondition', 'No active subscription.');
    }

    await ref.update({
      subscription: {
        ...subscription,
        status: 'cancelled',
        updatedAt: FieldValue.serverTimestamp(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { technicianId, status: 'cancelled' };
  },
);
