const { onCall, HttpsError } = require('firebase-functions/https');
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
