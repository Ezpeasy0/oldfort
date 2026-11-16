const { onCall, HttpsError } = require('firebase-functions/https');
const { onDocumentCreated } = require('firebase-functions/firestore');
const { setGlobalOptions } = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ region: 'asia-southeast1', maxInstances: 3 });

const LIMIT_PER_WINDOW = 10;
const WINDOW_MS = 10 * 60 * 1000;
const THAI_MOBILE_E164 = /^\+66[689]\d{8}$/;

async function allowRequest(ip) {
  const key = crypto.createHash('sha256').update(ip).digest('hex');
  const ref = db.collection('_rateLimits').doc(key);
  const now = Date.now();

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;

    if (!data || now - data.windowStart > WINDOW_MS) {
      tx.set(ref, { windowStart: now, count: 1 });
      return true;
    }
    if (data.count >= LIMIT_PER_WINDOW) return false;

    tx.update(ref, { count: data.count + 1 });
    return true;
  });
}

exports.checkPhone = onCall(async (request) => {
  const phone = request.data && request.data.phone;
  if (typeof phone !== 'string' || !THAI_MOBILE_E164.test(phone)) {
    throw new HttpsError('invalid-argument', 'invalid phone');
  }

  const ip = (request.rawRequest && request.rawRequest.ip) || 'unknown';
  if (!(await allowRequest(ip))) {
    throw new HttpsError('resource-exhausted', 'too many requests');
  }

  const snap = await db
    .collection('users')
    .where('phone', '==', phone)
    .limit(1)
    .get();

  return { registered: !snap.empty };
});

const STALE_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

function previewOf(message) {
  if (message.type === 'image') return 'ส่งรูปภาพ';
  if (message.type === 'audio') return 'ส่งข้อความเสียง';
  if (message.type === 'video') return 'ส่งวิดีโอ';
  const text = typeof message.text === 'string' ? message.text.trim() : '';
  if (!text) return 'ส่งข้อความใหม่';
  return text.length > 100 ? `${text.slice(0, 100)}…` : text;
}

exports.notifyNewMessage = onDocumentCreated(
  'chats/{chatId}/messages/{messageId}',
  async (event) => {
    const chatId = event.params.chatId;
    if (chatId.startsWith('community_')) return;

    const message = event.data && event.data.data();
    if (!message || typeof message.senderId !== 'string') return;

    const chatSnap = await db.collection('chats').doc(chatId).get();
    if (!chatSnap.exists) return;
    const chat = chatSnap.data();

    const recipients = (chat.memberIds || []).filter((uid) => uid !== message.senderId);
    if (recipients.length === 0) return;

    const senderSnap = await db.collection('publicProfiles').doc(message.senderId).get();
    const senderName = (senderSnap.exists && senderSnap.data().nickname) || 'เพื่อน';

    const isGroup = chat.type === 'group';
    const title = isGroup ? chat.name || 'แชทกลุ่ม' : senderName;
    const body = isGroup ? `${senderName}: ${previewOf(message)}` : previewOf(message);

    const deviceSnaps = await Promise.all(
      recipients.map((uid) => db.collection('users').doc(uid).collection('devices').get()),
    );
    const deviceRefs = deviceSnaps.flatMap((snap) => snap.docs.map((doc) => doc.ref));
    if (deviceRefs.length === 0) return;

    const result = await admin.messaging().sendEachForMulticast({
      tokens: deviceRefs.map((ref) => ref.id),
      notification: { title, body },
      data: { chatId },
      android: { priority: 'high', notification: { tag: chatId, channelId: 'chat_messages' } },
    });

    const cleanups = [];
    result.responses.forEach((res, i) => {
      if (!res.success && res.error && STALE_TOKEN_ERRORS.has(res.error.code)) {
        cleanups.push(deviceRefs[i].delete());
      }
    });
    await Promise.all(cleanups);
  },
);
