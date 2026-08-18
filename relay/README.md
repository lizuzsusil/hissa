# Hissa push relay

Delivers Hissa in-app notifications as FCM **data-only** pushes. A small
always-on Node process that replaces a Cloud Function: the app writes a
notification doc, the relay watches the collection and moves the bytes.

## Why this exists

FCM requires a service-account key or server key to send, and that secret must
never live in the app. The app therefore only **records intent** (a
rules-protected `notifications/{recipientId}_{eventKey}` doc); this relay
detects it and sends. The client renders the push from its `type` and routes it
locally.

## How it works

1. Watches `notifications` for undelivered docs (`added`/`modified`, plus a
   60s sweep to recover after downtime and to fire retries).
2. Resolves the recipient's active devices from `fcmTokens/{userId}/tokens/*`.
3. Sends one data-only FCM multicast (string-flattened payload; null extras
   dropped; `route` hint included).
4. Records state back on the doc:
   `pushStatus` (`pending|claiming|sent|skipped|failed`), `pushAttempts`,
   `pushNextRetryAt`, `pushDeliveredAt`, `pushDeviceCount`, `pushLastError`.
5. Retries transient failures with exponential backoff (30s → 1m → 2m → 4m → 8m,
   5 attempts max). Deactivates stale tokens
   (`active: false`) on `messaging/registration-token-not-registered` and friends.

Multi-instance safe: delivery is claimed via a Firestore transaction +
`pushLeaseUntil`, so two replicas never double-send the same doc.

## Run locally

```bash
cd relay
npm install
cp .env.example .env        # set GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json
# download the service account key from Firebase Console → Project settings → Service accounts
npm start
curl localhost:8080/healthz  # → ok
```

Needs a service account with `Cloud Messaging Admin` (or `Editor`) and
Firestore read/write.

## Deploy to Cloud Run

```bash
cd relay
gcloud builds submit --tag gcr.io/hissa-expense-tracker/hissa-push-relay .
gcloud run deploy hissa-push-relay \
  --image gcr.io/hissa-expense-tracker/hissa-push-relay \
  --region us-central1 \
  --service-account <relay-sa-email> \
  --min-instances 1 \
  --max-instances 3 \
  --allow-unauthenticated   # only if you want the /healthz endpoint reachable
```

Any single region works; notifications replicate.

## Tests

```bash
cd relay && npm test
```

Pure-logic tests (payload building, backoff) — no Firebase needed.
