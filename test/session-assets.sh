#!/bin/sh
# Managed provider assets are injected into only that Claude session. Strict
# MCP mode disables duplicate/conflicting user/project MCP definitions.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t crouter-session-assets)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

cat > "$TMP_DIR/claude" <<'MOCK'
#!/bin/sh
printf '%s\n' "$@" > "$CAPTURE_FILE"
exit 0
MOCK
chmod +x "$TMP_DIR/claude"

(
  info() { :; }
  die() { printf '%s\n' "$*" >&2; exit 1; }
  cleanup_provider_assets() { :; }
  CLAUDE_BIN="$TMP_DIR/claude"
  MODEL_OPUS=demo MODEL_SONNET=demo MODEL_HAIKU=demo MODEL_SUBAGENT=demo
  CONTEXT_TOKENS= EFFORT= AUTH_TOKEN= KEYPOOL_URL= KEYPOOL_PID= POST_STOP=
  AUTH_MODE=none BASE_URL=https://example.invalid PASSTHROUGH_ENV= NATIVE_BACKEND=
  PROVIDER_MCP_CONFIG="$TMP_DIR/provider-mcp.json"
  PROVIDER_PLUGIN_DIRS="$TMP_DIR/plugin one
$TMP_DIR/plugin two"
  PROVIDER_ASSET_ENV="CAPTURE_FILE=$TMP_DIR/args
PROVIDER_MARKER=active"
  EXTRA_ENV=
  . "$ROOT_DIR/lib/launch.sh"
  launch_claude demo 0
)

_args="$TMP_DIR/args"
grep -qx -- '--strict-mcp-config' "$_args" || { printf 'FAIL  strict MCP flag missing\n' >&2; exit 1; }
grep -qx -- '--mcp-config' "$_args" || { printf 'FAIL  MCP config flag missing\n' >&2; exit 1; }
grep -qx -- "$TMP_DIR/provider-mcp.json" "$_args" || { printf 'FAIL  MCP config path missing\n' >&2; exit 1; }
[ "$(grep -cx -- '--plugin-dir' "$_args")" -eq 2 ] || { printf 'FAIL  provider plugins not injected exactly once each\n' >&2; exit 1; }
grep -qx -- "$TMP_DIR/plugin one" "$_args" && grep -qx -- "$TMP_DIR/plugin two" "$_args" || {
  printf 'FAIL  provider plugin paths missing\n' >&2; exit 1;
}

printf 'ok    launch isolates provider MCPs and activates provider skills\n'
