#!/bin/sh
# Hermetic crouter-all route/catalog regressions. No real Keychain or network.
set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NODE_BIN=${NODE_BIN:-$(command -v node 2>/dev/null || true)}
[ -n "$NODE_BIN" ] || { printf 'skip  node not available\n'; exit 0; }

TEST_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t crouter-unified-routes)
trap 'rm -rf "$TEST_DIR"' EXIT INT TERM
FAKE_ROOT="$TEST_DIR/repo"
FAKE_BIN="$TEST_DIR/bin"
CAPTURE_FILE="$TEST_DIR/models.json"
mkdir -p "$FAKE_ROOT/bin" "$FAKE_ROOT/lib" "$FAKE_ROOT/providers" "$FAKE_BIN"
cp "$ROOT_DIR/bin/crouter" "$ROOT_DIR/bin/gateway" "$FAKE_ROOT/bin/"
cp "$ROOT_DIR/lib/"*.sh "$ROOT_DIR/lib/"*.js "$FAKE_ROOT/lib/"
cp "$ROOT_DIR/providers/openrouter.sh" "$ROOT_DIR/providers/antigravity.sh" \
  "$ROOT_DIR/providers/antigravity-claude.sh" "$FAKE_ROOT/providers/"
cat > "$FAKE_ROOT/providers/zz-demo.sh" <<'EOF'
PROVIDER_NAME="zz-demo"
PROVIDER_DESC="Alias-leak sentinel"
BASE_URL="http://127.0.0.1:9"
MODEL="demo-only"
AUTH_MODE="static"
AUTH_REFERENCE="local-test"
EOF
printf 'test\n' > "$FAKE_ROOT/VERSION"

cat > "$FAKE_BIN/security" <<'EOF'
#!/bin/sh
case "$1" in
  find-generic-password)
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -s) service=$2; shift 2 ;;
        *) shift ;;
      esac
    done
    [ "${service:-}" = openrouter-api-key ] || exit 44
    printf 'fake-openrouter-secret'
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$FAKE_BIN/security"

cat > "$FAKE_BIN/claude" <<EOF
#!/bin/sh
curl -sS "\$ANTHROPIC_BASE_URL/v1/models" > "$CAPTURE_FILE"
EOF
chmod +x "$FAKE_BIN/claude"

if env -u OPENROUTER_API_KEY PATH="$FAKE_BIN:$PATH" NODE_BIN="$NODE_BIN" \
  CLAUDE_BIN="$FAKE_BIN/claude" "$FAKE_ROOT/bin/crouter" all >/dev/null 2>&1; then
  :
else
  printf 'FAIL  crouter all did not start with OpenRouter Keychain fallback\n'
  exit 1
fi

if CAPTURE_FILE="$CAPTURE_FILE" "$NODE_BIN" <<'EOF'
const fs = require('fs');
const body = JSON.parse(fs.readFileSync(process.env.CAPTURE_FILE, 'utf8'));
const ids = body.data.map((entry) => entry.id);
if (!ids.includes('openrouter/openrouter/free')) process.exit(1);
EOF
then
  printf 'ok    crouter all includes OpenRouter from the Keychain fallback\n'
else
  printf 'FAIL  crouter all omitted OpenRouter despite its Keychain fallback\n'
  exit 1
fi

if CAPTURE_FILE="$CAPTURE_FILE" "$NODE_BIN" <<'EOF'
const fs = require('fs');
const body = JSON.parse(fs.readFileSync(process.env.CAPTURE_FILE, 'utf8'));
const ids = body.data.map((entry) => entry.id);
const expected = [
  'antigravity/gemini-3.1-pro-low',
  'antigravity/gemini-3.5-flash-low',
  'antigravity/gemini-3.1-pro-high',
  'antigravity/gemini-3-flash',
  'antigravity-claude/claude-opus-4-6-thinking',
  'antigravity-claude/claude-sonnet-4-6',
  'antigravity-claude/gpt-oss-120b-medium',
  'zz-demo/demo-only',
];
if (expected.some((id) => !ids.includes(id))) process.exit(1);
if (new Set(ids).size !== ids.length) process.exit(2);
if (ids.some((id) => id.startsWith('zz-demo/') && id !== 'zz-demo/demo-only')) process.exit(3);
EOF
then
  printf 'ok    unified catalog includes aliases once without cross-provider leakage\n'
else
  printf 'FAIL  unified catalog omitted, duplicated, or leaked model aliases\n'
  exit 1
fi

# Sequential loading exercises load_provider's reset contract independently of
# build_all_routes' per-provider subshells.
if ROOT_DIR="$FAKE_ROOT" PROVIDERS_DIR="$FAKE_ROOT/providers" sh <<'EOF'
die() { printf '%s\n' "$*" >&2; exit 1; }
. "$ROOT_DIR/lib/provider.sh"
load_provider antigravity
[ "$MODEL_ALIASES" = 'gemini-3.1-pro-high gemini-3-flash' ] || exit 1
load_provider zz-demo
[ -z "${MODEL_ALIASES:-}" ]
EOF
then
  printf 'ok    sequential provider loading resets model aliases\n'
else
  printf 'FAIL  model aliases leaked across sequential provider loads\n'
  exit 1
fi
