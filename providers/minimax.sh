#!/bin/sh
# Provider: MiniMax Token Plan (China Anthropic-compatible endpoint).
PROVIDER_NAME="minimax"
PROVIDER_DESC="MiniMax M3 via the China Anthropic-compatible endpoint"

BASE_URL="https://api.minimaxi.com/anthropic"
MODEL="MiniMax-M3"
CONTEXT_TOKENS="1048576"

# All Claude model aliases map to the single MiniMax model.
MODEL_OPUS="MiniMax-M3"
MODEL_SONNET="MiniMax-M3"
MODEL_HAIKU="MiniMax-M3"
MODEL_SUBAGENT="MiniMax-M3"

# Reasoning effort passed to Claude Code via --effort (low|medium|high|xhigh|max).
# MiniMax-M3's /anthropic endpoint supports the Anthropic `thinking` block (off by
# default, enable with adaptive). max = deepest adaptive thinking (largest budget).
EFFORT="max"

# Key pool resolved from macOS Keychain at launch. Add more service names here
# (space-separated) and the gateway auto-rotates between them on quota (429) /
# auth (401) errors, mid-session and transparently. Only the names are committed.
# The first entry below is the existing Token Plan key; append API / Coding Plan
# keys as you create them.
AUTH_MODE="keypool"
AUTH_KEYS="codex-minimax-token-plan"
# Optional second surface: MiniMax Coding Plan. Per your note its endpoint and
# supported models differ from the API/Token Plan, so it is declared separately.
# Leave commented until you have the plus-plan key(s); once set, claude-minimax
# will try this surface automatically after the API surface's keys are exhausted.
# PLUS_URL="https://api.minimaxi.com/anthropic"
# PLUS_KEYS="minimax-coding-1 minimax-coding-2"

# Extra environment, one KEY=VALUE per line.
EXTRA_ENV="API_TIMEOUT_MS=3000000
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

# Auto-wire MiniMax MCP (coding + generation) and the multimodal skill when a
# Token Plan key is present. Uses the official uvx method; gated by
# MINIMAX_AUTO_MCP (default 1) in config.sh. See bin/minimax-mcp-autosetup.
PRE_START="$ROOT_DIR/bin/minimax-mcp-autosetup"
POST_STOP=""
HEALTH_CHECK_URL=""
