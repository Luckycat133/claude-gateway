#!/bin/sh
# Hermetic gateway path-prefix regression. No provider credentials or network.
set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NODE_BIN=${NODE_BIN:-$(command -v node 2>/dev/null || true)}
[ -n "$NODE_BIN" ] || { printf 'skip  node not available\n'; exit 0; }
command -v python3 >/dev/null 2>&1 || {
  printf 'skip  python3 not available; cannot pick a free gateway port\n'
  exit 0
}

TEST_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t crouter-gateway-path)
UPSTREAM_PID=
GATEWAY_PID=
cleanup() {
  [ -n "$GATEWAY_PID" ] && kill "$GATEWAY_PID" 2>/dev/null || true
  [ -n "$UPSTREAM_PID" ] && kill "$UPSTREAM_PID" 2>/dev/null || true
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT INT TERM

cat > "$TEST_DIR/upstream.js" <<'EOF'
const fs = require('fs');
const http = require('http');
const seen = [];
let planAttempts = 0;
const server = http.createServer((req, res) => {
  const chunks = [];
  req.on('data', (chunk) => chunks.push(chunk));
  req.on('end', () => {
    const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    fs.writeFileSync(process.env.SEEN_PATH, req.url);
    fs.writeFileSync(process.env.SEEN_MODEL, body.model);
    fs.writeFileSync(process.env.SEEN_ENV_HEADER, req.headers['claude_code_disable_nonessential_traffic'] || '');
    if (req.url.startsWith('/ollama/')) {
      fs.writeFileSync(process.env.SEEN_NONE_HEADERS, JSON.stringify({
        authorization: req.headers.authorization || '',
        apiKey: req.headers['x-api-key'] || '',
        anthropicAuth: req.headers['anthropic-auth-token'] || '',
      }));
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end('{"ok":true}');
      return;
    }
    if (req.headers['anthropic-auth-token']) {
      fs.writeFileSync(process.env.SEEN_LOCAL_AUTH_HEADER, req.headers['anthropic-auth-token']);
    }
    const surface = req.headers.authorization ? 'plan' : req.headers['x-api-key'] ? 'api' : 'none';
    seen.push(surface);
    fs.writeFileSync(process.env.SEEN_SEQUENCE, seen.join(','));
    if (surface === 'plan') {
      const status = planAttempts++ === 0 ? 402 : 403;
      res.writeHead(status, { 'content-type': 'application/json' });
      res.end('{"error":"plan unavailable"}');
      return;
    }
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end('{"ok":true}');
  });
});
server.listen(0, '127.0.0.1', () => {
  fs.writeFileSync(process.env.PORT_FILE, String(server.address().port));
});
EOF

SEEN_PATH="$TEST_DIR/seen-path" SEEN_MODEL="$TEST_DIR/seen-model" \
  SEEN_ENV_HEADER="$TEST_DIR/seen-env-header" SEEN_SEQUENCE="$TEST_DIR/seen-sequence" \
  SEEN_LOCAL_AUTH_HEADER="$TEST_DIR/seen-local-auth-header" \
  SEEN_NONE_HEADERS="$TEST_DIR/seen-none-headers" \
  PORT_FILE="$TEST_DIR/upstream-port" \
  "$NODE_BIN" "$TEST_DIR/upstream.js" >/dev/null 2>&1 &
UPSTREAM_PID=$!
_i=0
while [ "$_i" -lt 50 ] && [ ! -s "$TEST_DIR/upstream-port" ]; do
  sleep 0.1
  _i=$((_i + 1))
done
UPSTREAM_PORT=$(cat "$TEST_DIR/upstream-port" 2>/dev/null || true)
[ -n "$UPSTREAM_PORT" ] || { printf 'FAIL  mock upstream did not start\n'; exit 1; }

cat > "$TEST_DIR/routes.json" <<EOF
[{"prefix":"demo","base_url":"http://127.0.0.1:$UPSTREAM_PORT/compat","candidates":[{"url":"http://127.0.0.1:$UPSTREAM_PORT/compat","auth":{"type":"bearer","token":"plan-token"},"model_map":{"demo-model":"plan-model"}},{"url":"http://127.0.0.1:$UPSTREAM_PORT/compat","auth":{"type":"x-api-key","token":"api-token"},"model_map":{"demo-model":"upstream-model"},"extra_env":["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"]}],"models":["demo-model"]},{"prefix":"local","base_url":"http://127.0.0.1:$UPSTREAM_PORT/ollama","candidates":[{"url":"http://127.0.0.1:$UPSTREAM_PORT/ollama","auth":{"type":"none","token":"ollama"}}],"models":["local-model"]}]
EOF

GATEWAY_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
CROUTER_ROUTES_FILE="$TEST_DIR/routes.json" CROUTER_GATEWAY_PORT="$GATEWAY_PORT" \
  CROUTER_GATEWAY_TOKEN="gateway-secret" CROUTER_CANDIDATE_COOLDOWN_MS=60000 \
  "$NODE_BIN" "$ROOT_DIR/bin/gateway" >"$TEST_DIR/gateway.out" 2>/dev/null &
GATEWAY_PID=$!
_i=0
while [ "$_i" -lt 50 ]; do
  grep -q '^CROUTER_GATEWAY_LISTENING_PORT=' "$TEST_DIR/gateway.out" 2>/dev/null && break
  sleep 0.1
  _i=$((_i + 1))
done
grep -q '^CROUTER_GATEWAY_LISTENING_PORT=' "$TEST_DIR/gateway.out" 2>/dev/null || {
  printf 'FAIL  gateway did not start\n'
  exit 1
}

UNAUTH_CODE=$(curl -sS -o "$TEST_DIR/unauthorized.body" -w '%{http_code}' \
  -X POST "http://127.0.0.1:$GATEWAY_PORT/v1/messages?beta=true" \
  -H 'content-type: application/json' \
  -d '{"model":"demo/demo-model","max_tokens":1,"messages":[]}')
[ "$UNAUTH_CODE" = 401 ] || {
  printf 'FAIL  gateway accepted an unauthenticated local request (HTTP %s)\n' "$UNAUTH_CODE" >&2
  exit 1
}

curl -sS -X POST "http://127.0.0.1:$GATEWAY_PORT/v1/messages?beta=true" \
  -H 'anthropic-auth-token: gateway-secret' \
  -H 'content-type: application/json' \
  -d '{"model":"demo/demo-model","max_tokens":1,"messages":[]}' >/dev/null
curl -sS -X POST "http://127.0.0.1:$GATEWAY_PORT/v1/messages?beta=true" \
  -H 'authorization: Bearer gateway-secret' \
  -H 'content-type: application/json' \
  -d '{"model":"demo/demo-model","max_tokens":1,"messages":[]}' >/dev/null

SEEN_PATH=$(cat "$TEST_DIR/seen-path" 2>/dev/null || true)
SEEN_MODEL=$(cat "$TEST_DIR/seen-model" 2>/dev/null || true)
SEEN_ENV_HEADER=$(cat "$TEST_DIR/seen-env-header" 2>/dev/null || true)
SEEN_SEQUENCE=$(cat "$TEST_DIR/seen-sequence" 2>/dev/null || true)
SEEN_LOCAL_AUTH_HEADER=$(cat "$TEST_DIR/seen-local-auth-header" 2>/dev/null || true)
if [ "$SEEN_PATH" = '/compat/v1/messages?beta=true' ] &&
   [ "$SEEN_MODEL" = upstream-model ] && [ -z "$SEEN_ENV_HEADER" ] &&
   [ -z "$SEEN_LOCAL_AUTH_HEADER" ] && [ "$SEEN_SEQUENCE" = plan,api,api ]; then
  printf 'ok    gateway cools failed plans, falls through to API, and applies each surface model map\n'
else
  printf 'FAIL  gateway forwarded path=%s model=%s env-header=%s local-auth-header=%s sequence=%s\n' \
    "$SEEN_PATH" "$SEEN_MODEL" "$SEEN_ENV_HEADER" "$SEEN_LOCAL_AUTH_HEADER" "$SEEN_SEQUENCE"
  exit 1
fi

curl -sS -X POST "http://127.0.0.1:$GATEWAY_PORT/v1/messages" \
  -H 'authorization: Bearer gateway-secret' \
  -H 'content-type: application/json' \
  -d '{"model":"local/local-model","max_tokens":1,"messages":[]}' >/dev/null

if NONE_HEADERS="$TEST_DIR/seen-none-headers" "$NODE_BIN" - <<'NODE'
const assert = require('assert');
const fs = require('fs');
const headers = JSON.parse(fs.readFileSync(process.env.NONE_HEADERS, 'utf8'));
assert.deepStrictEqual(headers, {
  authorization: 'Bearer ollama',
  apiKey: '',
  anthropicAuth: '',
});
NODE
then
  printf 'ok    gateway preserves Ollama dummy auth as Bearer-only\n'
else
  printf 'FAIL  gateway changed the Ollama dummy credential header shape\n' >&2
  exit 1
fi
