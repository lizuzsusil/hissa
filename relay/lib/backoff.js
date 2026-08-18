'use strict';

/** Hard cap on delivery attempts per notification before it is marked failed. */
const MAX_ATTEMPTS = 5;

const BASE_DELAY_MS = 30_000; // 30s, 1m, 2m, 4m, 8m
const CAP_MS = 8 * 60_000;

/** Exponential backoff for a given 1-based attempt number. */
function nextRetryDelayMs(attempt) {
  const exp = 2 ** Math.max(0, attempt - 1);
  return Math.min(BASE_DELAY_MS * exp, CAP_MS);
}

module.exports = { MAX_ATTEMPTS, nextRetryDelayMs };