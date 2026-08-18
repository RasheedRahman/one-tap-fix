import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

/**
 * Skill-based test (plan §5 technician verification): the technician
 * takes an in-app quiz; a score ≥ 70 marks the skill test as passed on
 * `technicians/{uid}.skillTest`. The question bank is client-side for
 * now — the callable only records the result with a server timestamp.
 */
export const submitSkillTest = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const score = request.data?.score as number | undefined;
    const total = request.data?.total as number | undefined;
    if (
      typeof score !== 'number' ||
      typeof total !== 'number' ||
      !Number.isInteger(score) ||
      !Number.isInteger(total) ||
      total <= 0 ||
      score < 0 ||
      score > total
    ) {
      throw new HttpsError('invalid-argument', 'Invalid score.');
    }

    const uid = request.auth.uid;
    const db = getFirestore();
    const ref = db.doc(`technicians/${uid}`);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Technician profile not found.');
    }
    const passed = score / total >= 0.7;

    await ref.update({
      skillTest: {
        status: passed ? 'passed' : 'failed',
        score,
        total,
        takenAt: FieldValue.serverTimestamp(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { status: passed ? 'passed' : 'failed', score, total };
  },
);
