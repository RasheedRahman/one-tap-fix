import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { haversineKm } from './matching';
import { BookingData } from './types';

const URBAN_SPEED_KMH = 30;
const ETA_FLOOR_MIN = 10;

/**
 * One-tap Accept (plan §3.3). Runs in a Firestore transaction so the
 * first technician to accept wins — no double-assignment.
 */
export const acceptJob = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const bookingId = request.data?.bookingId as string | undefined;
    if (!bookingId || typeof bookingId !== 'string') {
      throw new HttpsError('invalid-argument', 'bookingId required.');
    }
    const techUid = request.auth.uid;
    const db = getFirestore();
    const ref = db.doc(`bookings/${bookingId}`);

    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Booking not found.');
      }
      const booking = snap.data() as BookingData;
      if (booking.status !== 'matching') {
        throw new HttpsError('failed-precondition', 'BOOKING_UNAVAILABLE');
      }
      const candidates = booking.matching?.candidates ?? [];
      if (!candidates.includes(techUid)) {
        throw new HttpsError('failed-precondition', 'NOT_A_CANDIDATE');
      }

      const [techSnap, userSnap] = await Promise.all([
        tx.get(db.doc(`technicians/${techUid}`)),
        tx.get(db.doc(`users/${techUid}`)),
      ]);
      const tech = techSnap.data();
      const user = userSnap.data();

      const geo = booking.location?.geopoint;
      const techGeo = tech?.currentLocation?.geopoint;
      let etaMinutes = ETA_FLOOR_MIN;
      if (geo && techGeo) {
        const km = haversineKm(
          geo.latitude,
          geo.longitude,
          techGeo.latitude,
          techGeo.longitude,
        );
        etaMinutes = Math.max(
          ETA_FLOOR_MIN,
          Math.ceil((km / URBAN_SPEED_KMH) * 60),
        );
      }

      tx.update(ref, {
        technicianId: techUid,
        status: 'accepted',
        acceptedAt: new Date(),
        etaMinutes,
        technicianInfo: {
          name: user?.name ?? '',
          phone: user?.phone ?? '',
          rating: tech?.rating ?? 0,
        },
        updatedAt: new Date(),
      });

      // The job chat (plan §2.4) is created server-side on acceptance so
      // participants can start messaging immediately.
      tx.set(db.doc(`chats/${bookingId}`), {
        bookingId,
        customerId: booking.customerId,
        technicianId: techUid,
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      return { bookingId, status: 'accepted', etaMinutes, techUid };
    });

    // Notify the customer their technician is on the way.
    const bookingSnap = await ref.get();
    const booking = bookingSnap.data() as BookingData;
    await sendToUser(
      booking.customerId,
      'Technician accepted your booking',
      `A technician is on the way — ETA ~${result.etaMinutes} min`,
      { type: 'booking_accepted', bookingId },
    );

    return result;
  },
);

/** One-tap Decline: the technician leaves the candidate pool. */
export const rejectJob = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const bookingId = request.data?.bookingId as string | undefined;
    if (!bookingId || typeof bookingId !== 'string') {
      throw new HttpsError('invalid-argument', 'bookingId required.');
    }
    const techUid = request.auth.uid;
    const db = getFirestore();
    const ref = db.doc(`bookings/${bookingId}`);

    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Booking not found.');
      }
      const booking = snap.data() as BookingData;
      if (booking.status !== 'matching') {
        return { bookingId, status: 'ignored' };
      }

      const matching = booking.matching ?? {};
      const candidates = (matching.candidates ?? []).filter(
        (uid) => uid !== techUid,
      );
      const declined = [...(matching.declined ?? []), techUid];

      // No candidates left → back to pending so the retry scheduler
      // finds fresh technicians.
      const updates: Record<string, unknown> = {
        matching: {
          ...matching,
          candidates,
          declined,
        },
        updatedAt: new Date(),
      };
      if (candidates.length === 0) {
        updates.status = 'pending';
      }
      tx.update(ref, updates);

      return { bookingId, status: candidates.length === 0 ? 'pending' : 'matching' };
    });
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
    // Best-effort push; Firestore streams cover the UI.
  }
}
