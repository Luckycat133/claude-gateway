#!/bin/sh
# Uninstall may remove only shortcuts owned by this crouter checkout.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t crouter-uninstall-owner)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

printf 'user command\n' > "$TMP_DIR/crouter"
ln -s /usr/bin/true "$TMP_DIR/claude-minimax"
ln -s "$ROOT_DIR/bin/crouter-compat" "$TMP_DIR/claude-deepseek"

INSTALL_DIR="$TMP_DIR" CLAUDE_BIN=/usr/bin/true \
  "$ROOT_DIR/bin/crouter" uninstall -y >/dev/null

[ -f "$TMP_DIR/crouter" ] || {
  printf 'FAIL  uninstall removed a user-owned regular file\n' >&2
  exit 1
}
[ "$(readlink "$TMP_DIR/claude-minimax")" = /usr/bin/true ] || {
  printf 'FAIL  uninstall removed an unrelated symlink\n' >&2
  exit 1
}
[ ! -e "$TMP_DIR/claude-deepseek" ] && [ ! -L "$TMP_DIR/claude-deepseek" ] || {
  printf 'FAIL  uninstall left a crouter-owned shortcut\n' >&2
  exit 1
}

printf 'ok    uninstall preserves non-crouter files and links\n'
