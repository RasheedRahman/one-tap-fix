import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

/**
 * New chat message (plan §2.4):
 * - refreshes the chat summary (`lastMessage`/`lastMessageAt`)
 * - pushes an FCM notification to the other participant
 */
export const onChatMessageCreated = onDocumentCreated(
  { document: 'chats/{bookingId}/messages/{messageId}', timeoutSeconds: 120 },
  async (event) => {
    const message = event.data?.data();
    if (!message) return;
    const bookingId = event.params.bookingId;
    const senderId = message.senderId as string | undefined;
    if (!senderId) return;

    const db = getFirestore();
    const chatRef = db.doc(`chats/${bookingId}`);
    const chatSnap = await chatRef.get();
    if (!chatSnap.exists) return;
    const chat = chatSnap.data()!;
    const customerId = chat.customerId as string;
    const technicianId = chat.technicianId as string;
    const otherId = senderId === customerId ? technicianId : customerId;
    if (!otherId) return;

    const preview =
      message.type === 'image' ? 'Photo shared' : String(message.text ?? '');

    await chatRef.update({
      lastMessage: preview.slice(0, 120),
      lastMessageAt: message.createdAt ?? new Date(),
      updatedAt: new Date(),
    });

    await sendToUser(otherId, 'New message', preview || 'New message', {
      type: 'chat_message',
      chatId: bookingId,
      bookingId,
    });
  },
);

/**
 * Masked contact (plan §2.4): only participants of the booking may
 * retrieve the other party's `{name, phone}`. Numbers never appear in
 * client-readable Firestore data, so the raw digits stay access-
 * controlled server-side.
 */
export const getContact = onCall(
  { timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const bookingId = request.data?.bookingId as string | undefined;
    if (!bookingId || typeof bookingId !== 'string') {
      throw new HttpsError('invalid-argument', 'bookingId required.');
    }

    const db = getFirestore();
    const chatSnap = await db.doc(`chats/${bookingId}`).get();
    if (!chatSnap.exists) {
      throw new HttpsError('not-found', 'Chat not found.');
    }
    const chat = chatSnap.data()!;
    const uid = request.auth.uid;
    const isCustomer = chat.customerId === uid;
    const isTechnician = chat.technicianId === uid;
    if (!isCustomer && !isTechnician) {
      throw new HttpsError('permission-denied', 'Not part of this job.');
    }
    const otherId = isCustomer ? chat.technicianId : chat.customerId;

    const userSnap = await db.doc(`users/${otherId}`).get();
    if (!userSnap.exists) {
      throw new HttpsError('not-found', 'Contact not found.');
    }
    const user = userSnap.data()!;
    return {
      name: user.name ?? '',
      phone: user.phone ?? '',
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
    // Best-effort push; the chat stream covers the UI.
  }
}
