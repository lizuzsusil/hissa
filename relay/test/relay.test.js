'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');

const { buildData, routeFor } = require('../lib/payload');
const { nextRetryDelayMs, MAX_ATTEMPTS } = require('../lib/backoff');

test('buildData maps the core fields and route hint', () => {
  const data = buildData({
    id: 'u2_e_x',
    userId: 'u2',
    type: 'expenseAdded',
    actorUserId: 'u1',
    actorName: 'Ram',
    eventKey: 'e_x',
    spaceId: 'h1',
    extra: {},
  });
  assert.equal(data.type, 'expenseAdded');
  assert.equal(data.userId, 'u2');
  assert.equal(data.actorUserId, 'u1');
  assert.equal(data.actorName, 'Ram');
  assert.equal(data.eventKey, 'e_x');
  assert.equal(data.spaceId, 'h1');
  assert.equal(data.notificationId, 'u2_e_x');
  assert.equal(data.route, 'expenseDetail');
});

test('extra values are flattened to strings (FCM requires string values)', () => {
  const data = buildData({
    id: 'n1',
    userId: 'u2',
    type: 'expenseUpdated',
    actorUserId: 'u1',
    actorName: 'Sita',
    eventKey: 'e_y',
    spaceId: 'h1',
    extra: { amount: 100000, settlementId: 's_9' },
  });
  assert.equal(data['extra.amount'], '100000');
  assert.equal(data['extra.settlementId'], 's_9');
});

test('null/undefined extras and omitted spaceId are dropped', () => {
  const data = buildData({
    id: 'n2',
    userId: 'u2',
    type: 'spaceJoinApproved',
    actorUserId: 'u1',
    actorName: 'O',
    eventKey: 'j1',
    extra: { amount: null, note: undefined, keep: 0 },
  });
  assert.ok(!('spaceId' in data));
  assert.ok(!('extra.amount' in data));
  assert.ok(!('extra.note' in data));
  assert.equal(data['extra.keep'], '0');
  assert.equal(data.route, 'enterSpace');
});

test('routeFor covers every notification type with an inbox fallback', () => {
  const types = [
    'expenseAdded',
    'expenseUpdated',
    'settlementRecorded',
    'spaceInvited',
    'spaceJoinRequested',
    'spaceJoinApproved',
    'spaceJoinRejected',
    'groupRequested',
    'groupApproved',
    'groupRejected',
  ];
  for (const t of types) assert.ok(routeFor(t), `no route for ${t}`);
  assert.equal(routeFor('futureThing'), 'inbox');
});

test('backoff grows exponentially and never exceeds the cap', () => {
  assert.equal(nextRetryDelayMs(1), 30_000);
  assert.equal(nextRetryDelayMs(2), 60_000);
  assert.equal(nextRetryDelayMs(3), 120_000);
  assert.equal(nextRetryDelayMs(4), 240_000);
  assert.ok(nextRetryDelayMs(10) <= 8 * 60_000);
  assert.equal(MAX_ATTEMPTS, 5);
});