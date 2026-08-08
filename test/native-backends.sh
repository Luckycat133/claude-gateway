#!/bin/sh
# Bedrock and Vertex must use Claude Code's native signers, never invented
# model IDs or unowned localhost proxy processes.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t crouter-native)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

cat > "$TMP_DIR/claude" <<'MOCK'
#!/bin/sh
_capture_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "${CLAUDE_CODE_USE_BEDROCK:-}" = 1 ]; then
  _capture_file="$_capture_dir/bedrock"
else
  _capture_file="$_capture_dir/vertex"
fi
{
  printf 'bedrock=%s\n' "${CLAUDE_CODE_USE_BEDROCK:-}"
  printf 'vertex=%s\n' "${CLAUDE_CODE_USE_VERTEX:-}"
  printf 'aws_profile=%s\n' "${AWS_PROFILE:-}"
  printf 'vertex_project=%s\n' "${ANTHROPIC_VERTEX_PROJECT_ID:-}"
  printf 'base=%s\n' "${ANTHROPIC_BASE_URL:-}"
  printf 'api_key=%s\n' "${ANTHROPIC_API_KEY:-}"
  printf 'auth_token=%s\n' "${ANTHROPIC_AUTH_TOKEN:-}"
} > "$_capture_file"
MOCK
chmod +x "$TMP_DIR/claude"

CLAUDE_BIN="$TMP_DIR/claude" AWS_PROFILE=audit-profile \
  "$ROOT_DIR/bin/crouter" bedrock --version
grep -q '^bedrock=1$' "$TMP_DIR/bedrock"
grep -q '^aws_profile=audit-profile$' "$TMP_DIR/bedrock"
grep -q '^base=$' "$TMP_DIR/bedrock"
grep -q '^api_key=$' "$TMP_DIR/bedrock"
grep -q '^auth_token=$' "$TMP_DIR/bedrock"

CLAUDE_BIN="$TMP_DIR/claude" ANTHROPIC_VERTEX_PROJECT_ID=audit-project \
  "$ROOT_DIR/bin/crouter" vertex --version
grep -q '^vertex=1$' "$TMP_DIR/vertex"
grep -q '^vertex_project=audit-project$' "$TMP_DIR/vertex"
grep -q '^base=$' "$TMP_DIR/vertex"

printf 'ok    Bedrock and Vertex launch through native Claude Code backends\n'
