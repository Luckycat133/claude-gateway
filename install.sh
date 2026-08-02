#!/bin/sh
# Install crouter as a global command via a symlink.
set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERSION=$(cat "$ROOT_DIR/VERSION" 2>/dev/null || echo "unknown")
INSTALL_DIR=${INSTALL_DIR:-$HOME/.local/bin}

mkdir -p "$INSTALL_DIR"
ln -sf "$ROOT_DIR/bin/crouter" "$INSTALL_DIR/crouter"
chmod +x "$ROOT_DIR/bin/crouter"

# All compatibility shortcuts are symlinks to the single shared launcher, which
# derives the provider from the invoked name (strips the "claude-" prefix).
chmod +x "$ROOT_DIR/bin/crouter-compat"
for shortcut in claude-minimax claude-antigravity claude-antigravity-claude claude-deepseek; do
  ln -sf "$ROOT_DIR/bin/crouter-compat" "$INSTALL_DIR/$shortcut"
done

if [ ! -f "$ROOT_DIR/config.sh" ]; then
  cp "$ROOT_DIR/config.example.sh" "$ROOT_DIR/config.sh"
  echo "Created config.sh from config.example.sh (edit as needed; it is gitignored)."
fi

echo "Installed: $INSTALL_DIR/crouter -> $ROOT_DIR/bin/crouter"
echo "Installed compatibility shortcuts: claude-minimax, claude-antigravity, claude-antigravity-claude, claude-deepseek"
echo "crouter $VERSION"

case :$PATH: in
  *:"$INSTALL_DIR":*) ;;
  *) echo "NOTE: $INSTALL_DIR is not on your PATH." ;;
esac

echo "Try: crouter list"
echo "Optional: enable shell autocompletion - see README (completions/)."