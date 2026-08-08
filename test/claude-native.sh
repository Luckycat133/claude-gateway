#!/bin/sh
# `crouter claude` is a transparent native Claude Code entry point. It must
# leave Anthropic's own login/OAuth resolution inside Claude Code instead of
# forcing the credential through crouter's HTTP proxies.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t crouter-claude-native)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

cat > "$TMP_DIR/claude" <<'EOF'
#!/bin/sh
{
  printf 'home=%s\n' "$HOME"
  printf 'oauth=%s\n' "${CLAUDE_CODE_OAUTH_TOKEN:-}"
  printf 'base=%s\n' "${ANTHROPIC_BASE_URL:-}"
  printf 'api=%s\n' "${ANTHROPIC_API_KEY:-}"
  printf 'auth=%s\n' "${ANTHROPIC_AUTH_TOKEN:-}"
  printf 'args='
  printf '<%s>' "$@"
  printf '\n'
} > "$CAPTURE_FILE"
EOF
chmod +x "$TMP_DIR/claude"

CAPTURE_FILE="$TMP_DIR/explicit" CLAUDE_BIN="$TMP_DIR/claude" \
  CLAUDE_CODE_OAUTH_TOKEN=oauth-sentinel \
  env -u ANTHROPIC_BASE_URL -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN \
  "$ROOT_DIR/bin/crouter" claude --version

grep -qx "home=$HOME" "$TMP_DIR/explicit"
grep -qx 'oauth=oauth-sentinel' "$TMP_DIR/explicit"
grep -qx 'base=' "$TMP_DIR/explicit"
grep -qx 'api=' "$TMP_DIR/explicit"
grep -qx 'auth=' "$TMP_DIR/explicit"
grep -qx 'args=<--version>' "$TMP_DIR/explicit"

# No explicit credential is also valid here: the real Claude binary may read
# the subscription login that it owns in the macOS Keychain.
CAPTURE_FILE="$TMP_DIR/stored-login" CLAUDE_BIN="$TMP_DIR/claude" \
  env -u CLAUDE_CODE_OAUTH_TOKEN -u ANTHROPIC_BASE_URL \
      -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN \
  "$ROOT_DIR/bin/crouter" claude
grep -qx 'oauth=' "$TMP_DIR/stored-login"
grep -qx 'base=' "$TMP_DIR/stored-login"
grep -qx 'api=' "$TMP_DIR/stored-login"
grep -qx 'auth=' "$TMP_DIR/stored-login"

printf 'ok    crouter claude preserves native Claude login and OAuth resolution\n'
