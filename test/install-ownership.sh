#!/bin/sh
# Install must preflight command-name collisions before creating any symlink.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t crouter-install-owner)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

FAKE_ROOT="$TMP_DIR/repo"
INSTALL_DIR="$TMP_DIR/bin"
mkdir -p "$FAKE_ROOT/bin" "$FAKE_ROOT/providers" "$INSTALL_DIR"
cp "$ROOT_DIR/install.sh" "$ROOT_DIR/config.example.sh" "$ROOT_DIR/VERSION" "$FAKE_ROOT/"
cp "$ROOT_DIR/bin/crouter" "$ROOT_DIR/bin/crouter-compat" \
  "$ROOT_DIR/bin/antigravity-proxy-patch" "$FAKE_ROOT/bin/"
printf 'PROVIDER_NAME="demo"\nBASE_URL="https://example.invalid"\nMODEL="demo"\n' \
  > "$FAKE_ROOT/providers/demo.sh"
printf 'user command\n' > "$INSTALL_DIR/crouter"

if INSTALL_DIR="$INSTALL_DIR" PATH="$PATH" sh "$FAKE_ROOT/install.sh" >/dev/null 2>&1; then
  printf 'FAIL  installer accepted a user-owned command collision\n' >&2
  exit 1
fi
grep -q '^user command$' "$INSTALL_DIR/crouter" || {
  printf 'FAIL  installer overwrote the user-owned command\n' >&2
  exit 1
}
[ ! -e "$INSTALL_DIR/claude-demo" ] && [ ! -L "$INSTALL_DIR/claude-demo" ] || {
  printf 'FAIL  installer made partial changes before collision failure\n' >&2
  exit 1
}

printf 'ok    installer preflights and preserves command-name collisions\n'
