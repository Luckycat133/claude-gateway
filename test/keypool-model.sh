#!/bin/sh
# The local failover proxy must rewrite the logical model per candidate while
# preserving the candidate's declared authentication header.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NODE_BIN=${NODE_BIN:-$(command -v node)}
TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t crouter-keypool-model)
UP_PID=
POOL_PID=
trap 'kill "${POOL_PID:-}" "${UP_PID:-}" 2>/dev/null || true; rm -rf "$TMP_DIR"' EXIT INT TERM

cat > "$TMP_DIR/upstream.js" <<'NODE'
const fs = require('fs');
const http = require('http');
const server = http.createServer((req, res) => {
  const chunks = [];
  req.on('data', (chunk) => chunks.push(chunk));
  req.on('end', () => {
    const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    fs.writeFileSync(process.env.CAPTURE_FILE, JSON.stringify({
      model: body.model,
      authorization: req.headers.authorization || '',
      apiKey: req.headers['x-api-key'] || '',
      anthropicAuth: req.headers['anthropic-auth-token'] || '',
    }));
    res.writeHead(200, {'content-type': 'application/json'});
    res.end('{"ok":true}');
  });
});
server.listen(0, '127.0.0.1', () => {
  fs.writeFileSync(process.env.PORT_FILE, String(server.address().port));
});
NODE

CAPTURE_FILE="$TMP_DIR/capture.json" PORT_FILE="$TMP_DIR/upstream.port" \
  "$NODE_BIN" "$TMP_DIR/upstream.js" >/dev/null 2>&1 &
UP_PID=$!

_i=0
while [ "$_i" -lt 50 ] && [ ! -s "$TMP_DIR/upstream.port" ]; do
  sleep 0.05
  _i=$((_i + 1))
done
[ -s "$TMP_DIR/upstream.port" ] || { printf 'FAIL  mock upstream did not start\n' >&2; exit 1; }
_up_port=$(cat "$TMP_DIR/upstream.port")

_candidates=$(printf '[{"url":"http://127.0.0.1:%s","type":"bearer","token":"plan-secret","model_map":{"logical-model":"upstream-model"},"label":"plan"}]' "$_up_port")
KEYPOOL_CANDIDATES="$_candidates" KEYPOOL_PORT=0 KEYPOOL_CLIENT_TOKEN=local-secret \
  "$NODE_BIN" "$ROOT_DIR/bin/keypool-proxy" > "$TMP_DIR/pool.out" 2> "$TMP_DIR/pool.err" &
POOL_PID=$!

_i=0
_pool_port=
while [ "$_i" -lt 50 ]; do
  _pool_port=$(sed -n 's/^KEYPOOL_LISTENING_PORT=//p' "$TMP_DIR/pool.out" | head -n 1)
  [ -n "$_pool_port" ] && break
  sleep 0.05
  _i=$((_i + 1))
done
[ -n "$_pool_port" ] || { printf 'FAIL  keypool did not start\n' >&2; exit 1; }

curl -fsS -X POST "http://127.0.0.1:$_pool_port/v1/messages" \
  -H 'anthropic-auth-token: local-secret' \
  -H 'content-type: application/json' \
  -d '{"model":"logical-model","messages":[]}' >/dev/null

CAPTURE_FILE="$TMP_DIR/capture.json" "$NODE_BIN" - <<'NODE'
const assert = require('assert');
const capture = require(process.env.CAPTURE_FILE);
assert.strictEqual(capture.model, 'upstream-model');
assert.strictEqual(capture.authorization, 'Bearer plan-secret');
assert.strictEqual(capture.apiKey, '');
assert.strictEqual(capture.anthropicAuth, '');
NODE

printf 'ok    keypool rewrites mapped logical models and preserves auth shape\n'
