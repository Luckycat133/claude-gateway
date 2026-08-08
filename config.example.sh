#!/bin/sh
# crouter local configuration.
#
# Copy this file to config.sh and adjust. config.sh is gitignored and must
# never contain API keys - keys belong in Keychain / env vars / a command
# (see AUTH_MODE in providers/*.sh).
#
# This file is sourced by bin/crouter after ROOT_DIR is set, so you
# may reference $ROOT_DIR and $HOME.

# Path to the Claude Code binary. Default: `command -v claude`.
#CLAUDE_BIN="$HOME/.local/bin/claude"

# Where runtime logs are written. Default: $ROOT_DIR/logs
#LOG_DIR="$ROOT_DIR/logs"

# Antigravity proxy checkout and listen port.
# Defaults: $ROOT_DIR/antigravity-claude-proxy and 18080.
#ANTIGRAVITY_PROXY_DIR="$ROOT_DIR/antigravity-claude-proxy"
#ANTIGRAVITY_PORT=18080

# MiniMax auto-MCP wiring. When `crouter minimax` starts and a Token Plan key
# (Keychain service `codex-minimax-token-plan`) is present, two official MCP
# servers (minimax-coding, minimax-gen) and the multimodal skill are registered
# automatically via the official uvx method. Set either to 0 to disable.
#MINIMAX_AUTO_MCP=1
#MINIMAX_AUTO_SKILL=1

# Bypass permissions mode. When 1, every `crouter <provider>` launch injects
# `--dangerously-skip-permissions` so Claude Code skips all permission prompts.
# Default: 0 (off). Set to 1 to enable by default. SECURITY: grants Claude Code
# unrestricted command execution for the session; only on trusted projects.
#BYPASS_PERMISSIONS=0
