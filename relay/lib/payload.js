'use strict';

/**
 * Route hint the client can use before resolving the final screen. The app
 * ultimately decides from `type`; this is informational only.
 */
const ROUTES = {
  expenseAdded: 'expenseDetail',
  expenseUpdated: 'expenseDetail',
  settlementRecorded: 'settle',
  spaceInvited: 'space',
  spaceJoinRequested: 'space',
  spaceJoinApproved: 'enterSpace',
  spaceJoinRejected: 'inbox',
  groupRequested: 'groups',
  groupApproved: 'groups',
  groupRejected: 'inbox',
};

function routeFor(type) {
  return ROUTES[type] || 'inbox';
}

/**
 * Build the FCM data payload. FCM `data` maps only carry strings, so every
 * value is stringified; null/undefined extras are dropped.
 */
function buildData(notification) {
  const data = {
    type: notification.type,
    userId: notification.userId,
    actorUserId: notification.actorUserId || '',
    actorName: notification.actorName || '',
    eventKey: notification.eventKey || '',
    notificationId: notification.id,
    route: routeFor(notification.type),
  };
  if (notification.spaceId) data.spaceId = notification.spaceId;
  const extra = notification.extra || {};
  for (const [key, value] of Object.entries(extra)) {
    if (value != null) data[`extra.${key}`] = String(value);
  }
  return data;
}

module.exports = { buildData, routeFor };