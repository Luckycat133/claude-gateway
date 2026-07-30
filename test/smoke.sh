#!/bin/sh
# Minimal offline smoke test for claude-gateway.
# Requires no keychain entry or network access.
set -u
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GATEWAY="$ROOT_DIR/bin/claude-gateway"
fail=0

ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

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
