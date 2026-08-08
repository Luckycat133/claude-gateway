#!/bin/sh
# A direct launch must reap a surface pool if provider asset preparation fails
# before launch_claude installs its own lifecycle trap.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NODE_BIN=${NODE_BIN:-$(command -v node 2>/dev/null || true)}
[ -n "$NODE_BIN" ] || { printf 'skip  node not available\n'; exit 0; }

TEST_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t crouter-prelaunch-cleanup)
POOL_PID_FILE="$TEST_DIR/pool.pid"
cleanup() {
  if [ -s "$POOL_PID_FILE" ]; then
    _pool_pid=$(cat "$POOL_PID_FILE")
    kill "$_pool_pid" 2>/dev/null || true
  fi
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT INT TERM

FAKE_ROOT="$TEST_DIR/repo"
FAKE_BIN="$TEST_DIR/bin"
mkdir -p "$FAKE_ROOT/bin" "$FAKE_ROOT/lib" "$FAKE_ROOT/providers" "$FAKE_BIN"
cp "$ROOT_DIR/bin/crouter" "$FAKE_ROOT/bin/"
cp "$ROOT_DIR/lib/"*.sh "$ROOT_DIR/lib/"*.js "$FAKE_ROOT/lib/"
printf 'test\n' > "$FAKE_ROOT/VERSION"

cat > "$FAKE_ROOT/providers/demo.sh" <<'EOF'
PROVIDER_NAME="demo"
BASE_URL="https://example.invalid/anthropic"
MODEL="demo-model"
AUTH_MODE="surfaces"
PLAN_URL="https://example.invalid/anthropic"
PLAN_AUTH_TYPE="bearer"
PLAN_KEYS="demo-plan-key"
PLAN_MODEL="demo-model"
ASSET_PLUGIN_DIRS="$ROOT_DIR/missing-plugin"
EOF

# Implements the process contract used by start_surface_pool: print the chosen
# port, stay alive, and expose the PID so the test can assert lifecycle cleanup.
cat > "$FAKE_ROOT/bin/keypool-proxy" <<'EOF'
const fs = require('fs');
const http = require('http');
const server = http.createServer((_req, res) => res.end('{}'));
server.listen(0, '127.0.0.1', () => {
  fs.writeFileSync(process.env.POOL_PID_FILE, String(process.pid));
  process.stdout.write(`KEYPOOL_LISTENING_PORT=${server.address().port}\n`);
});
EOF

cat > "$FAKE_BIN/security" <<'EOF'
#!/bin/sh
case "$1" in
  find-generic-password) printf 'fake-plan-secret' ;;
  *) exit 1 ;;
esac
EOF
cat > "$FAKE_BIN/claude" <<'EOF'
#!/bin/sh
printf 'FAIL  Claude should not start after asset preparation fails\n' >&2
exit 99
EOF
chmod +x "$FAKE_BIN/security" "$FAKE_BIN/claude"

set +e
PATH="$FAKE_BIN:$PATH" NODE_BIN="$NODE_BIN" CLAUDE_BIN="$FAKE_BIN/claude" \
  POOL_PID_FILE="$POOL_PID_FILE" "$FAKE_ROOT/bin/crouter" demo \
  >"$TEST_DIR/crouter.out" 2>&1
_rc=$?
set -e

[ "$_rc" -ne 0 ] || {
  printf 'FAIL  asset preparation failure returned exit 0\n' >&2
  exit 1
}
grep -q 'provider asset plugin not found' "$TEST_DIR/crouter.out" || {
  printf 'FAIL  direct launch did not reach the intended asset failure\n' >&2
  exit 1
}
[ -s "$POOL_PID_FILE" ] || {
  printf 'FAIL  surface pool did not start before the asset failure\n' >&2
  exit 1
}

_pool_pid=$(cat "$POOL_PID_FILE")
_i=0
while [ "$_i" -lt 30 ] && kill -0 "$_pool_pid" 2>/dev/null; do
  sleep 0.1
  _i=$((_i + 1))
done
if kill -0 "$_pool_pid" 2>/dev/null; then
  printf 'FAIL  surface pool survived provider asset preparation failure\n' >&2
  exit 1
fi

printf 'ok    prelaunch asset failure reaps the surface pool\n'
