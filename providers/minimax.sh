#!/bin/sh
# Provider: MiniMax M3 (China Anthropic-compatible endpoint).
PROVIDER_NAME="minimax"
PROVIDER_DESC="MiniMax M3 via the China Anthropic-compatible endpoint"

BASE_URL="https://api.minimaxi.com/anthropic"
MODEL="MiniMax-M3"
CONTEXT_TOKENS="1048576"

MODEL_OPUS="MiniMax-M3"
MODEL_SONNET="MiniMax-M3"
MODEL_HAIKU="MiniMax-M3"
MODEL_SUBAGENT="MiniMax-M3"

# MiniMax M3 supports adaptive thinking.
EFFORT="max"

AUTH_MODE="keypool"
AUTH_KEYS="codex-minimax-token-plan"

EXTRA_ENV="API_TIMEOUT_MS=3000000
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

# Configure MiniMax MCP servers and the multimodal skill when credentials are
# available. Controlled by MINIMAX_AUTO_MCP; see bin/minimax-mcp-autosetup.
PRE_START="$ROOT_DIR/bin/minimax-mcp-autosetup"
POST_STOP=""
HEALTH_CHECK_URL=""
