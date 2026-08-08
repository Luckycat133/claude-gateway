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
const server = http.createServer((req, res) => {
  fs.writeFileSync(process.env.SEEN_PATH, req.url);
  req.resume();
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end('{"ok":true}');
});
server.listen(0, '127.0.0.1', () => {
  fs.writeFileSync(process.env.PORT_FILE, String(server.address().port));
});
EOF

SEEN_PATH="$TEST_DIR/seen-path" PORT_FILE="$TEST_DIR/upstream-port" \
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
[{"prefix":"demo","base_url":"http://127.0.0.1:$UPSTREAM_PORT/compat","candidates":[{"url":"http://127.0.0.1:$UPSTREAM_PORT/compat","auth":{"type":"none","token":"test"},"extra_env":[]}],"models":["demo-model"]}]
EOF

GATEWAY_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
CROUTER_ROUTES_FILE="$TEST_DIR/routes.json" CROUTER_GATEWAY_PORT="$GATEWAY_PORT" \
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

curl -sS -X POST "http://127.0.0.1:$GATEWAY_PORT/v1/messages?beta=true" \
  -H 'content-type: application/json' \
  -d '{"model":"demo/demo-model","max_tokens":1,"messages":[]}' >/dev/null

SEEN_PATH=$(cat "$TEST_DIR/seen-path" 2>/dev/null || true)
if [ "$SEEN_PATH" = '/compat/v1/messages?beta=true' ]; then
  printf 'ok    gateway appends /v1/messages once to the provider path prefix\n'
else
  printf 'FAIL  gateway forwarded path %s\n' "$SEEN_PATH"
  exit 1
fi
