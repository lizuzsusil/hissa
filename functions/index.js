/**
 * Hissa Firebase Cloud Functions
 *
 * Delivers FCM push notifications and transactional emails for the Space
 * lifecycle:
 *
 *   member group creation requests (existing)
 *     request submitted  -> Space owner + requester are notified
 *     request approved   -> requester + all newly-grouped members are notified
 *     request rejected   -> requester is notified (no one else)
 *
 *   email member invites
 *     a member is invited by email -> an invitation email is sent to them
 *
 *   space join requests (invite-code based)
 *     request submitted  -> Space owner is emailed + notified; requester gets
 *                           a push confirmation
 *     request approved   -> requester is emailed + notified
 *     request rejected   -> requester is emailed + notified
 *
 * Notifications fire as Firestore *triggers*, so they only run after the
 * underlying write has committed successfully.
 *
 * Recipient devices are resolved through the `fcmTokens/{userId}` collection,
 * which the app keeps fresh on every sign-in and token rotation. Emails are
 * sent through Gmail SMTP (nodemailer) using the `SMTP_USER` / `SMTP_PASS`
 * secrets (see `firebase functions:secrets:set`); when these are unset, email
 * sending is skipped and the functions still deliver push notifications.
 * Locally the emulator fills the same values from `functions/.env`.
 */
const { defineSecret } = require('firebase-functions/params');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

const smtpUser = defineSecret('SMTP_USER');
const smtpPass = defineSecret('SMTP_PASS');

admin.initializeApp();

const db = admin.firestore();

/** Display name for a user profile, falling back to a neutral label. */
async function userDisplayName(userId) {
  try {
    const snap = await db.collection('users').doc(userId).get();
    const name = snap.data()?.name;
    return typeof name === 'string' && name.trim() !== '' ? name.trim() : 'A member';
  } catch (_) {
    return 'A member';
  }
}

/** Display name for a space, falling back to a neutral label. */
async function spaceName(spaceId) {
  try {
    const snap = await db.collection('spaces').doc(spaceId).get();
    const name = snap.data()?.name;
    return typeof name === 'string' && name.trim() !== '' ? name.trim() : 'your space';
  } catch (_) {
    return 'your space';
  }
}

/** Email address of a user profile, if one is stored (auth users have one). */
async function userEmail(userId) {
  try {
    const snap = await db.collection('users').doc(userId).get();
    return snap.data()?.email;
  } catch (_) {
    return undefined;
  }
}

/**
 * Sends a push notification to a single user's current device. Missing or
 * stale tokens are ignored so a failed delivery never fails the document
 * event that triggered it.
 */
async function sendToUser(userId, { title, body, type = 'group_request' }) {
  if (!userId) return;
  try {
    const tokenSnap = await db.collection('fcmTokens').doc(userId).get();
    const token = tokenSnap.data()?.token;
    if (typeof token !== 'string' || token === '') return;
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: { type },
    });
  } catch (_) {
    // Unregistered token, messaging quota, transient failure: best-effort.
  }
}

/** A tiny HTML email wrapper for the plain-text notification bodies. */
function emailBody(text) {
  return `<div style="font-family: Arial, Helvetica, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
    <p style="font-size: 15px; line-height: 1.6;">${text}</p>
    <p style="color: #777777; font-size: 12px; margin-top: 24px;">Sent by Hissa · Space Expense Tracker</p>
  </div>`;
}

/**
 * Sends a transactional email through Gmail SMTP. Requires the SMTP_USER /
 * SMTP_PASS secrets; when they are not configured, sending is skipped
 * entirely so the functions degrade gracefully.
 */
async function sendEmail({ to, subject, html }) {
  if (!to) return;
  const user = smtpUser.value();
  const pass = smtpPass.value();
  if (!user || !pass) return;
  try {
    const transport = nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 465,
      secure: true,
      auth: { user, pass },
    });
    await transport.sendMail({
      from: `"Hissa" <${user}>`,
      to,
      subject,
      html,
    });
  } catch (_) {
    // Best-effort: a failed email must never fail the document event.
  }
}

// ---------------------------------------------------------------------------
// Member group creation request lifecycle (FCM only)
// ---------------------------------------------------------------------------

/**
 * A member (non-owner) submitted a group creation request. The Space owner is
 * asked to review it, and the requester gets confirmation that it is pending
 * approval.
 */
exports.sendGroupRequestNotifications = onDocumentCreated(
  'groupRequests/{requestId}',
  async (event) => {
    const request = event.data.data();
    if (!request || !request.spaceId || !request.requesterUserId) return;
    const { spaceId, requesterUserId } = request;

    const [requesterName, space] = await Promise.all([
      userDisplayName(requesterUserId),
      spaceName(spaceId),
    ]);

    // Space owner: a new request needs their approval.
    const ownerSnap = await db
      .collection('spaceMembers')
      .where('spaceId', '==', spaceId)
      .where('role', '==', 'owner')
      .limit(1)
      .get();
    if (!ownerSnap.empty) {
      const owner = ownerSnap.docs[0].data();
      await sendToUser(owner.userId, {
        title: 'New group request',
        body: `${requesterName} requested to create a member group in ${space}.`,
      });
    }

    // Requester: confirmation that the request was submitted and is pending.
    await sendToUser(requesterUserId, {
      title: 'Group request submitted',
      body: 'Your group creation request was submitted and is pending approval.',
    });
  },
);

/**
 * A request changed status. On approval the requester and every member of the
 * newly created group are notified; on rejection only the requester is, since
 * no group was created.
 */
exports.sendGroupRequestDecisionNotifications = onDocumentUpdated(
  'groupRequests/{requestId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after || before?.status === after.status) return;

    const { spaceId, requesterUserId } = after;

    if (after.status === 'approved') {
      // Requester: their group is live.
      await sendToUser(requesterUserId, {
        title: 'Group approved',
        body: 'Your group creation request was approved. Your member group is ready to use.',
      });

      // The approval wrote the group and its members before updating the
      // request status, so the group already exists by the time this trigger
      // runs. Members are the non-owner users in the freshly created group.
      const groupSnap = await db
        .collection('memberGroups')
        .where('spaceId', '==', spaceId)
        .where('ownerUserId', '==', requesterUserId)
        .orderBy('createdAt', 'desc')
        .limit(1)
        .get();
      if (groupSnap.empty) return;
      const group = groupSnap.docs[0].data();

      const memberSnap = await db
        .collection('memberGroupMembers')
        .where('groupId', '==', group.id)
        .get();
      for (const doc of memberSnap.docs) {
        const member = doc.data();
        if (!member.userId || member.userId === requesterUserId) continue;
        await sendToUser(member.userId, {
          title: 'Group approved',
          body: `You've been added to ${group.name} in ${await spaceName(spaceId)}.`,
        });
      }
    } else if (after.status === 'rejected') {
      // Requester only: the outcome, without notifying other members.
      await sendToUser(requesterUserId, {
        title: 'Group request rejected',
        body: 'Your group creation request was rejected by the space owner.',
      });
    }
  },
);

// ---------------------------------------------------------------------------
// Email member invites
// ---------------------------------------------------------------------------

/**
 * A member was added to a Space through an email invite (the membership doc
 * carries an `invitedEmail` field). Send an invitation email to that address.
 */
exports.sendMemberInviteEmail = onDocumentCreated(
  'spaceMembers/{memberId}',
  { secrets: [smtpUser, smtpPass] },
  async (event) => {
    const member = event.data.data();
    const email = member?.invitedEmail;
    if (typeof email !== 'string' || email === '') return;
    const spaceId = member.spaceId;
    if (!spaceId) return;

    const [space, inviterName] = await Promise.all([
      spaceName(spaceId),
      userDisplayName(member.invitedByUserId),
    ]);

    await sendEmail({
      to: email,
      subject: `You've been invited to ${space} on Hissa`,
      html: emailBody(
        `${inviterName} invited you to join the space <b>${space}</b> in Hissa. ` +
          'Open the Hissa app to see the space, its members and shared expenses.',
      ),
    });
  },
);

// ---------------------------------------------------------------------------
// Space join requests (invite-code based)
// ---------------------------------------------------------------------------

/**
 * A user submitted a request to join a Space with an invite code. The Space
 * owner is emailed and notified (joining is never immediate), and the
 * requester gets a push confirmation that the request is pending.
 */
exports.sendSpaceJoinRequestNotifications = onDocumentCreated(
  'spaceJoinRequests/{requestId}',
  { secrets: [smtpUser, smtpPass] },
  async (event) => {
    const request = event.data.data();
    if (!request || !request.spaceId || !request.requesterUserId) return;
    const { spaceId, requesterUserId } = request;

    const [requesterName, space] = await Promise.all([
      userDisplayName(requesterUserId),
      spaceName(spaceId),
    ]);

    const ownerSnap = await db
      .collection('spaceMembers')
      .where('spaceId', '==', spaceId)
      .where('role', '==', 'owner')
      .limit(1)
      .get();
    if (!ownerSnap.empty) {
      const owner = ownerSnap.docs[0].data();
      await sendToUser(owner.userId, {
        title: 'New join request',
        body: `${requesterName} requested to join ${space}.`,
        type: 'space_join_request',
      });
      await sendEmail({
        to: await userEmail(owner.userId),
        subject: `New join request for ${space}`,
        html: emailBody(
          `<b>${requesterName}</b> requested to join <b>${space}</b>. ` +
            'Approve or reject the request in the Hissa app.',
        ),
      });
    }

    // Requester: confirmation that the request was submitted and is pending.
    await sendToUser(requesterUserId, {
      title: 'Join request submitted',
      body: `Your request to join ${space} is pending approval.`,
      type: 'space_join_request',
    });
  },
);

/**
 * A Space join request changed status. On approval (or rejection) the
 * requester is emailed and notified of the outcome. The membership write for
 * an approval happens before the status update, so the requester can open the
 * Space as soon as this trigger runs.
 */
exports.sendSpaceJoinRequestDecisionNotifications = onDocumentUpdated(
  'spaceJoinRequests/{requestId}',
  { secrets: [smtpUser, smtpPass] },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after || before?.status === after.status) return;

    const { spaceId, requesterUserId } = after;
    const space = await spaceName(spaceId);
    const requesterEmail = await userEmail(requesterUserId);

    if (after.status === 'approved') {
      await sendToUser(requesterUserId, {
        title: 'You joined a new space',
        body: `Your request to join ${space} was approved. You can now open the space.`,
        type: 'space_join_request',
      });
      await sendEmail({
        to: requesterEmail,
        subject: `You've been accepted to ${space}`,
        html: emailBody(
          `Your request to join <b>${space}</b> was approved by the owner. ` +
            'Open the Hissa app to start tracking expenses together.',
        ),
      });
    } else if (after.status === 'rejected') {
      await sendToUser(requesterUserId, {
        title: 'Join request declined',
        body: `Your request to join ${space} was declined by the owner.`,
        type: 'space_join_request',
      });
      await sendEmail({
        to: requesterEmail,
        subject: `Join request declined for ${space}`,
        html: emailBody(
          `Your request to join <b>${space}</b> was declined by the space owner.`,
        ),
      });
    }
  },
);