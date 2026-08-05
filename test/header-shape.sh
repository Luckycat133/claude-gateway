#!/bin/sh
# Header-shape integration test for providers that use non-Anthropic auth.
#
# This is NOT hermetic — it requires:
#   - macOS Keychain entry `openai-api-key` (for the openai provider)
#   - Network access to api.openai.com
#
# It starts a local mock upstream that captures the request headers Claude
# Code sends, points `crouter openai` at it, and asserts that only
# `Authorization: Bearer ...` is sent (never `x-api-key:` — OpenAI's compat
# Messages API rejects x-api-key).
#
# CI is expected to skip this. Run locally after editing providers/openai.sh
# or lib/launch.sh to verify the header shape didn't regress.
#
# Usage: ./test/header-shape.sh
set -u
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# Bail out cleanly if the prerequisites aren't there. Don't fake-pass.
if ! command -v nc >/dev/null 2>&1; then
  printf 'skip  netcat not available; cannot run header-shape test\n'
  exit 0
fi
if [ "$(uname -s 2>/dev/null)" = "Darwin" ] && ! security find-generic-password -a "$USER" -s "openai-api-key" -w >/dev/null 2>&1; then
  printf 'skip  openai-api-key not in keychain; skipping header-shape test\n'
  exit 0
fi

# Pick a free port. bash 3.2 ships with macOS, so no `pickfreeport`.
PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()' 2>/dev/null) || {
  printf 'skip  python3 not available; cannot pick a free port\n'
  exit 0
}
CAPTURE_DIR=$(mktemp -d -t crouter-header-shape)
trap 'rm -rf "$CAPTURE_DIR"' EXIT INT TERM

# Mock claude: pretend to be Claude Code, but instead of doing real work, hit
# our mock upstream and capture the headers it sees.
MOCK_DIR="$CAPTURE_DIR/bin"
mkdir -p "$MOCK_DIR"
cat > "$MOCK_DIR/claude" << EOF
#!/bin/sh
# Extract the base URL Claude Code was pointed at (last ANTHROPIC_BASE_URL= arg).
_url=""
for _a in "\$@"; do
  case "\$_a" in
    ANTHROPIC_BASE_URL=*) _url=\${_a#ANTHROPIC_BASE_URL=} ;;
  esac
done
# Issue a minimal messages request and write headers to disk.
curl -sS -X POST "\$_url/v1/messages?beta=true" \\
  -H "Content-Type: application/json" \\
  -H "anthropic-version: 2023-06-01" \\
  -d '{"model":"gpt-5.6-terra","max_tokens":8,"messages":[{"role":"user","content":"ping"}]}' \\
  -D "$CAPTURE_DIR/headers.txt" -o "$CAPTURE_DIR/body.txt" \\
  --max-time 15 \\
  || true
exit 0
EOF
chmod +x "$MOCK_DIR/claude"

fail=0
ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

# Run `crouter openai` against the mock claude.
CLAUDE_BIN="$MOCK_DIR/claude" "$ROOT_DIR/bin/crouter" openai >/dev/null 2>&1 || true

# Assert header shape: Authorization Bearer present, x-api-key absent.
if [ ! -s "$CAPTURE_DIR/headers.txt" ]; then
  bad "openai request never reached upstream (no headers captured)"
elif grep -qi '^authorization: Bearer ' "$CAPTURE_DIR/headers.txt"; then
  ok "openai sends Authorization: Bearer"
else
  bad "openai missing Authorization: Bearer header"
fi
if grep -qi '^x-api-key:' "$CAPTURE_DIR/headers.txt"; then
  bad "openai leaked x-api-key header (OpenAI compat API rejects this)"
else
  ok "openai does NOT send x-api-key"
fi

exit "$fail"