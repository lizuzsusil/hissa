'use strict';

/**
 * Hissa push relay — delivers in-app notifications as FCM data pushes.
 *
 * A small always-on process (Cloud Run / App Engine Flex / any VM) that
 * replaces what would otherwise be a Cloud Function. It:
 *
 *   1. watches the `notifications` collection for undelivered docs,
 *   2. resolves the recipient's active device tokens,
 *   3. sends a data-only FCM message per device (client renders it in the
 *      foreground/background handler and routes by `type`),
 *   4. records delivery state back on the notification doc — idempotent via a
 *      lease-based claim so multiple instances never double-send,
 *   5. retries transient failures with exponential backoff and deactivates
 *      stale device tokens.
 *
 * It contains no business logic: the app decides WHO/WHAT/WHY and writes the
 * notification; this relay only moves bytes.
 */

const http = require('node:http');

let admin;
try {
  admin = require('firebase-admin');
} catch (err) {
  console.error('Missing dependency: run `npm install` inside relay/ first.');
  process.exit(1);
}

const { buildData } = require('./lib/payload');
const { nextRetryDelayMs, MAX_ATTEMPTS } = require('./lib/backoff');

const LEASE_MS = 30_000; // how long a delivery claim is held
const SWEEP_INTERVAL_MS = 60_000; // pick up retries + docs missed while down
const PORT = Number(process.env.PORT || 8080);

// Whole-call failures that mean "try again later".
const RETRYABLE_SEND_ERRORS = new Set([
  'messaging/internal-error',
  'messaging/server-unavailable',
  'messaging/rate-limit-exceeded',
]);

// Per-token failures that mean "this device is dead, stop sending to it".
const PERMANENT_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-argument',
  'messaging/invalid-registration-token',
  'messaging/sender-id-mismatch',
  'messaging/invalid-apns-credentials',
]);

function log(msg) {
  console.log(`[relay ${new Date().toISOString()}] ${msg}`);
}

async function main() {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
  const db = admin.firestore();
  const messaging = admin.messaging();
  const notificationsRef = db.collection('notifications');
  const inFlight = new Set();

  // ---------- tokens ----------

  async function activeTokensFor(userId) {
    const snap = await db
      .collection('fcmTokens')
      .doc(userId)
      .collection('tokens')
      .where('active', '==', true)
      .get();
    return snap.docs.map((d) => ({ deviceId: d.id, token: d.data().token }));
  }

  async function deactivateDevice(userId, deviceId) {
    try {
      await db
        .collection('fcmTokens')
        .doc(userId)
        .collection('tokens')
        .doc(deviceId)
        .update({
          active: false,
          deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (_) {
      /* already gone */
    }
  }

  // ---------- delivery state ----------

  async function mark(ref, fields) {
    try {
      await ref.update({
        ...fields,
        pushUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      log(`mark failed for ${ref.id}: ${err.message}`);
    }
  }

  async function scheduleRetry(ref, error) {
    let attempts = 1;
    try {
      const snap = await ref.get();
      attempts = (snap.data() && snap.data().pushAttempts) || 1;
    } catch (_) {}
    if (attempts >= MAX_ATTEMPTS) {
      log(`giving up on ${ref.id} after ${attempts} attempts: ${error}`);
      await mark(ref, { pushStatus: 'failed', pushLastError: error });
      return;
    }
    await mark(ref, {
      pushStatus: 'pending',
      pushLastError: error,
      pushNextRetryAt: Date.now() + nextRetryDelayMs(attempts),
    });
  }

  // ---------- claiming ----------

  /**
   * Atomically claim a notification for delivery. Only one instance can hold
   * the lease, so horizontal scaling never double-sends. Returns true only if
   * THIS call took the lease.
   */
  async function claim(ref, now) {
    let claimed = false;
    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) return;
        const d = snap.data();
        const done = d.pushStatus === 'sent' || d.pushStatus === 'failed' || d.pushStatus === 'skipped';
        if (done) return;
        if (d.pushLeaseUntil && d.pushLeaseUntil > now) return; // held by someone
        tx.update(ref, {
          pushStatus: 'claiming',
          pushClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
          pushLeaseUntil: now + LEASE_MS,
          pushAttempts: admin.firestore.FieldValue.increment(1),
        });
        claimed = true;
      });
    } catch (err) {
      log(`claim failed for ${ref.id}: ${err.message}`);
    }
    return claimed;
  }

  // ---------- delivery ----------

  async function deliver(ref, notification) {
    const userId = notification.userId;
    if (!userId) {
      await mark(ref, { pushStatus: 'skipped', pushLastError: 'missing recipient' });
      return;
    }

    let devices;
    try {
      devices = await activeTokensFor(userId);
    } catch (err) {
      await scheduleRetry(ref, err.message); // transient Firestore error
      return;
    }
    if (devices.length === 0) {
      await mark(ref, { pushStatus: 'skipped', pushLastError: 'no active devices' });
      return;
    }

    let res;
    try {
      res = await messaging.sendEachForMulticast({
        tokens: devices.map((d) => d.token),
        data: buildData(notification),
      });
    } catch (err) {
      const code = err.code || '';
      if (code === 'messaging/authentication-error') {
        await mark(ref, { pushStatus: 'failed', pushLastError: err.message }); // config problem, do not retry
        return;
      }
      if (RETRYABLE_SEND_ERRORS.has(code)) {
        await scheduleRetry(ref, err.message);
        return;
      }
      await mark(ref, { pushStatus: 'failed', pushLastError: err.message });
      return;
    }

    let delivered = 0;
    let dead = 0;
    for (let i = 0; i < res.responses.length; i++) {
      const r = res.responses[i];
      if (r.success) {
        delivered++;
        continue;
      }
      const code = r.error && r.error.code;
      const device = devices[i];
      if (device && PERMANENT_TOKEN_ERRORS.has(code)) {
        dead++;
        await deactivateDevice(userId, device.deviceId);
      }
    }

    if (delivered > 0) {
      await mark(ref, {
        pushStatus: 'sent',
        pushDeliveredAt: admin.firestore.FieldValue.serverTimestamp(),
        pushDeviceCount: delivered,
      });
      return;
    }
    if (dead > 0) {
      await mark(ref, { pushStatus: 'skipped', pushLastError: 'no valid devices' });
      return;
    }
    await scheduleRetry(ref, 'token-level transient failure');
  }

  // ---------- entry point per doc ----------

  async function handleDoc(doc) {
    if (!doc.exists) return;
    const data = doc.data();
    const id = doc.id;
    if (inFlight.has(id)) return;
    const status = data.pushStatus;
    if (status === 'sent' || status === 'failed' || status === 'skipped') return;
    const now = Date.now();
    if (data.pushNextRetryAt && data.pushNextRetryAt > now) return;

    inFlight.add(id);
    try {
      if (await claim(doc.ref, now)) {
        await deliver(doc.ref, data);
      }
    } catch (err) {
      log(`handler error for ${id}: ${err.message}`);
    } finally {
      inFlight.delete(id);
    }
  }

  // ---------- watchers ----------

  const unsubscribe = notificationsRef.onSnapshot(
    (snap) => {
      for (const change of snap.docChanges()) {
        if (change.type === 'added' || change.type === 'modified') {
          handleDoc(change.doc).catch((err) => log(`handler error: ${err.message}`));
        }
      }
    },
    (err) => log(`snapshot error: ${err.message}`),
  );

  // Startup recovery + retry sweep. Docs written while the relay was down have
  // no `pushStatus` yet, so exclude only `sent` and filter the rest in memory.
  async function sweep() {
    const now = Date.now();
    try {
      const snap = await notificationsRef.where('pushStatus', '!=', 'sent').get();
      for (const doc of snap.docs) {
        const d = doc.data();
        if (d.pushStatus === 'failed' || d.pushStatus === 'skipped') continue;
        if (d.pushLeaseUntil && d.pushLeaseUntil > now) continue;
        if (d.pushNextRetryAt && d.pushNextRetryAt > now) continue;
        handleDoc(doc).catch((err) => log(`sweep error: ${err.message}`));
      }
    } catch (err) {
      log(`sweep failed: ${err.message}`);
    }
  }

  const sweepTimer = setInterval(sweep, SWEEP_INTERVAL_MS);
  sweep();

  // ---------- health server (required by Cloud Run / App Engine) ----------

  const server = http.createServer((req, res) => {
    if (req.url === '/healthz' || req.url === '/') {
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end('ok');
      return;
    }
    res.writeHead(404);
    res.end();
  });
  server.listen(PORT, () => log(`relay listening on :${PORT}`));

  // ---------- shutdown ----------

  async function shutdown() {
    log('shutting down');
    server.close();
    unsubscribe();
    clearInterval(sweepTimer);
    try {
      await db.terminate();
    } catch (_) {}
    process.exit(0);
  }
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error(`fatal: ${err.message}`);
  process.exit(1);
});