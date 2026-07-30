#!/bin/sh
# Install claude-gateway as a global command via a symlink.
set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERSION=$(cat "$ROOT_DIR/VERSION" 2>/dev/null || echo "unknown")
INSTALL_DIR=${INSTALL_DIR:-$HOME/.local/bin}

mkdir -p "$INSTALL_DIR"
ln -sf "$ROOT_DIR/bin/claude-gateway" "$INSTALL_DIR/claude-gateway"
chmod +x "$ROOT_DIR/bin/claude-gateway"

if [ ! -f "$ROOT_DIR/config.sh" ]; then
  cp "$ROOT_DIR/config.example.sh" "$ROOT_DIR/config.sh"
  echo "Created config.sh from config.example.sh (edit as needed; it is gitignored)."
fi

echo "Installed: $INSTALL_DIR/claude-gateway -> $ROOT_DIR/bin/claude-gateway"
echo "claude-gateway $VERSION"

case :$PATH: in
  *:"$INSTALL_DIR":*) ;;
  *) echo "NOTE: $INSTALL_DIR is not on your PATH." ;;
esac

echo "Try: claude-gateway list"
echo "Optional: enable shell autocompletion - see README (completions/)."
