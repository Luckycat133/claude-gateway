'use strict';

// Shared request/auth/failover primitives for the direct keypool proxy and the
// namespaced unified gateway. The two servers keep different routing semantics
// but must agree on local authentication and candidate health.

const RETRYABLE_STATUSES = new Set([401, 402, 403, 429]);
const STRIPPED_HEADERS = new Set([
  'host',
  'authorization',
  'x-api-key',
  'anthropic-auth-token',
  'connection',
  'proxy-connection',
]);

function requestToken(headers) {
  const authorization = String(headers.authorization || '');
  if (authorization.slice(0, 7).toLowerCase() === 'bearer ') return authorization.slice(7);
  return String(headers['x-api-key'] || headers['anthropic-auth-token'] || '');
}

function forwardHeaders(source, dropContentLength) {
  const headers = {};
  for (const [name, value] of Object.entries(source)) {
    const lower = name.toLowerCase();
    if (STRIPPED_HEADERS.has(lower)) continue;
    if (dropContentLength && (lower === 'content-length' || lower === 'transfer-encoding')) continue;
    headers[name] = value;
  }
  return headers;
}

function applyAuth(headers, type, token, noneAsBearer) {
  if (type === 'none') {
    if (noneAsBearer) headers.authorization = 'Bearer ' + (token || 'crouter');
  } else if (type === 'x-api-key') {
    headers['x-api-key'] = token;
  } else if (type === 'bearer') {
    headers.authorization = 'Bearer ' + token;
  } else if (type === 'both') {
    headers.authorization = 'Bearer ' + token;
    headers['x-api-key'] = token;
  } else {
    throw new Error('unsupported candidate auth type: ' + type);
  }
  return headers;
}

function parseCooldownMs(value) {
  const raw = value === undefined || value === '' ? '300000' : String(value);
  const parsed = Number(raw);
  if (!Number.isFinite(parsed) || parsed < 0 || !Number.isInteger(parsed)) {
    throw new Error('CROUTER_CANDIDATE_COOLDOWN_MS must be a non-negative integer');
  }
  return parsed;
}

function retryAfterMs(headers, now) {
  if (!headers) return 0;
  const rawValue = headers['retry-after'];
  const raw = Array.isArray(rawValue) ? rawValue[0] : rawValue;
  if (raw === undefined || raw === null || String(raw).trim() === '') return 0;
  const value = String(raw).trim();
  if (/^\d+(?:\.\d+)?$/.test(value)) return Math.ceil(Number(value) * 1000);
  const at = Date.parse(value);
  return Number.isFinite(at) ? Math.max(0, at - now) : 0;
}

function createCandidateCooldown(count, value) {
  const baseMs = parseCooldownMs(value);
  const unavailableUntil = Array.from({length: count}, () => 0);

  return {
    order() {
      const now = Date.now();
      const active = [];
      const cooling = [];
      for (let index = 0; index < count; index += 1) {
        if (unavailableUntil[index] <= now) active.push(index);
        else cooling.push(index);
      }
      cooling.sort((left, right) => unavailableUntil[left] - unavailableUntil[right] || left - right);
      // Cooling candidates stay at the tail as a last resort if every healthy
      // candidate also fails during this request.
      return active.concat(cooling);
    },
    fail(index, headers) {
      const now = Date.now();
      unavailableUntil[index] = now + Math.max(baseMs, retryAfterMs(headers, now));
    },
    clear(index) {
      unavailableUntil[index] = 0;
    },
  };
}

module.exports = {
  applyAuth,
  createCandidateCooldown,
  forwardHeaders,
  isRetryableStatus: (status) => RETRYABLE_STATUSES.has(status),
  requestToken,
};
