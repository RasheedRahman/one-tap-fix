import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

/**
 * Ratings & reviews (plan §2.4): a customer rates a completed job once
 * (`reviews/{bookingId}`). This trigger keeps the technician's aggregate
 * rating on `technicians/{uid}` incrementally in sync and pushes an FCM
 * notification when a new review lands.
 */
export const onReviewWritten = onDocumentWritten(
  { document: 'reviews/{bookingId}', timeoutSeconds: 120 },
  async (event) => {
    const db = getFirestore();
    const before = event.data?.before ?? null;
    const after = event.data?.after ?? null;

    const technicianId = after
      ? (after.data()?.technicianId as string | undefined)
      : before
        ? (before.data()?.technicianId as string | undefined)
        : undefined;
    if (!technicianId) return;
    const techRef = db.doc(`technicians/${technicianId}`);

    const delta = computeDelta(before?.data() ?? null, after?.data() ?? null);
    if (!delta) return;

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(techRef);
      if (!snap.exists) return;
      const tech = snap.data()!;
      const ratingSum = (tech.ratingSum as number) || 0;
      const ratingsCount = (tech.ratingsCount as number) || 0;

      const nextSum = Math.max(0, ratingSum + delta.sum);
      const nextCount = Math.max(0, ratingsCount + delta.count);

      tx.update(techRef, {
        ratingSum: nextSum,
        ratingsCount: nextCount,
        rating: nextCount === 0 ? 0 : nextSum / nextCount,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    // Notify the technician about brand-new reviews only.
    if (delta.count > 0) {
      await sendToUser(
        technicianId,
        'New review',
        'A customer rated you. Check your profile.',
        { type: 'new_review', bookingId: event.params.bookingId },
      );
    }
  },
);

function computeDelta(
  before: Record<string, any> | null,
  after: Record<string, any> | null,
): { sum: number; count: number } | null {
  const bRating = before && typeof before.rating === 'number' ? before.rating : 0;
  const aRating = after && typeof after.rating === 'number' ? after.rating : 0;
  if (before === null && after === null) return null;
  return { sum: aRating - bRating, count: (after ? 1 : 0) - (before ? 1 : 0) };
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
    // Best-effort push; profile streams cover the UI.
  }
}
