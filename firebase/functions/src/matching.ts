import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { BookingData } from './types';

const EARTH_RADIUS_KM = 6371;

export function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const RADIUS_KM = { normal: 25, emergency: 15 };
const CANDIDATE_LIMIT = 5;
const MATCH_TIMEOUT_MIN = { normal: 30, emergency: 10 };
const MAX_ATTEMPTS = 2;

export interface CandidateScore {
  uid: string;
  score: number;
  distanceKm: number;
}

interface TechnicianSnapshot {
  uid: string;
  skills: string[];
  rating: number;
  currentLocation?: {
    geopoint: { latitude: number; longitude: number };
  };
}

/** Smart auto-matching: skill + rating + distance + availability. */
export async function findCandidates(
  booking: BookingData,
  declined: string[],
): Promise<CandidateScore[]> {
  const db = getFirestore();

  const techSnap = await db
    .collection('technicians')
    .where('isAvailable', '==', true)
    .limit(200)
    .get();

  const bookingLat = booking.location?.geopoint?.latitude;
  const bookingLng = booking.location?.geopoint?.longitude;
  if (bookingLat == null || bookingLng == null) return [];

  const radius = booking.isEmergency ? RADIUS_KM.emergency : RADIUS_KM.normal;
  const declinedSet = new Set(declined ?? []);

  const scored: CandidateScore[] = [];

  techSnap.forEach((doc) => {
    const tech = { uid: doc.id, ...doc.data() } as unknown as TechnicianSnapshot;

    // Skill match.
    if (!tech.skills?.includes(booking.categoryId)) return;
    // Availability already filtered by the query.
    if (declinedSet.has(tech.uid)) return;
    // Needs a live location to be reachable.
    const geo = tech.currentLocation?.geopoint;
    if (!geo || geo.latitude == null || geo.longitude == null) return;

    const distanceKm = haversineKm(
      bookingLat,
      bookingLng,
      geo.latitude,
      geo.longitude,
    );
    if (distanceKm > radius) return;

    // Score: 40% rating, 60% distance (0–100).
    const ratingScore = Math.min(1, (tech.rating ?? 0) / 5) * 40;
    const distanceScore = (1 - distanceKm / radius) * 60;
    scored.push({
      uid: tech.uid,
      score: Math.round((ratingScore + distanceScore) * 100) / 100,
      distanceKm: Math.round(distanceKm * 100) / 100,
    });
  });

  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, CANDIDATE_LIMIT);
}

/** Runs the matching pass for a booking (create trigger + retry scheduler). */
export async function runMatching(docId: string): Promise<void> {
  const db = getFirestore();
  const ref = db.doc(`bookings/${docId}`);

  const outcome = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const booking = snap.data() as BookingData;

    // Only re-match bookings still waiting for a technician.
    if (booking.status !== 'pending' && booking.status !== 'matching') {
      return null;
    }

    const previous = booking.matching ?? {};
    const attemptCount = (previous.attemptCount ?? 0) + 1;
    const declined = previous.declined ?? [];

    const candidates = await findCandidates(booking, declined);
    const now = FieldValue.serverTimestamp();

    if (candidates.length === 0) {
      tx.update(ref, {
        status: 'pending',
        matching: {
          ...previous,
          candidates: [],
          declined,
          attemptCount,
          startedAt: now,
        },
        updatedAt: now,
      });
      return null;
    }

    tx.update(ref, {
      status: 'matching',
      matching: {
        ...previous,
        candidates: candidates.map((c) => c.uid),
        scores: Object.fromEntries(
          candidates.map((c) => [c.uid, c.score]),
        ),
        distances: Object.fromEntries(
          candidates.map((c) => [c.uid, c.distanceKm]),
        ),
        declined,
        attemptCount,
        startedAt: now,
      },
      updatedAt: now,
    });

    return { booking, candidates };
  });

  // Notify candidates after commit (FCM is not transactional).
  if (outcome) {
    await notifyCandidates(docId, outcome.booking, outcome.candidates);
  }
}

export async function notifyCandidates(
  docId: string,
  booking: BookingData,
  candidates: CandidateScore[],
): Promise<void> {
  const db = getFirestore();
  const messaging = getMessaging();

  for (const candidate of candidates) {
    const userSnap = await db.doc(`users/${candidate.uid}`).get();
    const token = userSnap.data()?.fcmToken as string | undefined;
    if (!token) continue;

    try {
      await messaging.send({
        token,
        notification: {
          title: `New job: ${booking.categoryName}`,
          body: `₹${booking.pricing?.estimatedTotal ?? ''} · ${candidate.distanceKm} km away`,
        },
        data: {
          type: 'new_job',
          bookingId: docId,
        },
        android: { priority: 'high' },
      });
    } catch (_) {
      // Unregistered token — the app stream still surfaces the offer.
    }
  }
}

// ---------------------------------------------------------------------
// Triggers
// ---------------------------------------------------------------------

/** Booking created by a customer → start matching. */
export const onBookingCreated = onDocumentCreated(
  { document: 'bookings/{bookingId}', timeoutSeconds: 120 },
  async (event) => {
    const booking = event.data?.data() as BookingData | undefined;
    if (!booking || booking.status !== 'pending') return;
    await runMatching(event.params.bookingId);
  },
);

/**
 * Retry + timeout scheduler, runs every minute.
 * - matching/pending bookings older than the timeout get a new matching
 *   pass (wider pool via declined-exclusion),
 * - after MAX_ATTEMPTS with no technician, the booking is cancelled.
 */
export const retryMatching = onSchedule(
  { schedule: 'every 1 minutes', timeoutSeconds: 300 },
  async () => {
    const db = getFirestore();
    const now = Date.now();

    const matching = await db
      .collection('bookings')
      .where('status', '==', 'matching')
      .get();
    const pendingRetry = await db
      .collection('bookings')
      .where('status', '==', 'pending')
      .where('matching.startedAt', '!=', null)
      .get();

    const docs = [...matching.docs, ...pendingRetry.docs];
    for (const doc of docs) {
      const booking = doc.data() as BookingData;
      const startedAt = booking.matching?.startedAt;
      if (!startedAt) continue;

      const startedMillis = startedAt instanceof Timestamp
        ? startedAt.toMillis()
        : startedAt.getTime();
      const timeoutMin = booking.isEmergency
        ? MATCH_TIMEOUT_MIN.emergency
        : MATCH_TIMEOUT_MIN.normal;
      if (now - startedMillis < timeoutMin * 60_000) continue;

      const attemptCount = booking.matching?.attemptCount ?? 0;
      if (attemptCount >= MAX_ATTEMPTS) {
        await doc.ref.update({
          status: 'cancelled',
          cancellationReason: 'no_technician_available',
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        await runMatching(doc.id);
      }
    }
  },
);
