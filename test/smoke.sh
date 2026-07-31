#!/bin/sh
# Minimal offline smoke test for claude-gateway.
# Requires no keychain entry or network access.
set -u
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GATEWAY="$ROOT_DIR/bin/claude-gateway"
fail=0

# Create a temporary mock claude binary so the test doesn't depend on a global installation.
MOCK_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'mock_claude')
MOCK_CLAUDE="$MOCK_DIR/claude"
cat > "$MOCK_CLAUDE" << 'EOF'
#!/bin/sh
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-V" ]; then
  echo "0.2.0"
  exit 0
fi
exit 0
EOF
chmod +x "$MOCK_CLAUDE"

# Clean up on exit
trap 'rm -rf "$MOCK_DIR"' EXIT INT TERM

# Export CLAUDE_BIN for the launchers
export CLAUDE_BIN="$MOCK_CLAUDE"

ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

# Legacy command names remain available as local compatibility launchers.
for legacy in claude-minimax claude-antigravity claude-antigravity-claude; do
  if "$ROOT_DIR/bin/$legacy" --version 2>/dev/null | grep -qE '[0-9]+\.[0-9]+\.[0-9]+'; then
    ok "$legacy compatibility launcher forwards --version"
  else
    bad "$legacy compatibility launcher is unavailable"
  fi
done

# --version prints a semver
if "$GATEWAY" --version 2>/dev/null | grep -qE '[0-9]+\.[0-9]+\.[0-9]+'; then
  ok "--version prints a semver"
else
  bad "--version did not print a semver"
fi

# -V short flag also prints a semver
if "$GATEWAY" -V 2>/dev/null | grep -qE '[0-9]+\.[0-9]+\.[0-9]+'; then
  ok "-V prints a semver"
else
  bad "-V did not print a semver"
fi

# list shows the known providers
if "$GATEWAY" list 2>/dev/null | grep -q 'minimax'; then
  ok "list shows minimax provider"
else
  bad "list missing minimax provider"
fi

# help exits 0
if "$GATEWAY" help >/dev/null 2>&1; then
  ok "help exits 0"
else
  bad "help failed"
fi

# an unknown subcommand is rejected (non-zero exit)
if "$GATEWAY" bogus-command >/dev/null 2>&1; then
  bad "unknown subcommand was accepted"
else
  ok "unknown subcommand rejected"
fi

[ "$fail" -eq 0 ] && echo "All smoke tests passed." || echo "Some smoke tests FAILED."
exit "$fail"
