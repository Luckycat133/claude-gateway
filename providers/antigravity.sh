#!/bin/sh
# Provider: Gemini models through the local Antigravity compatibility proxy.
. "$ROOT_DIR/lib/antigravity-common.sh"

PROVIDER_NAME="antigravity"
PROVIDER_DESC="Gemini models via the local Antigravity proxy"

BASE_URL=$(antigravity_base_url)
MODEL="gemini-3.6-flash-medium"
CONTEXT_TOKENS="1048576"

# Gemini 3.6 Flash only; low/medium/high map to the haiku/sonnet/opus tiers.
MODEL_OPUS="gemini-3.6-flash-high"
MODEL_SONNET="gemini-3.6-flash-medium"
MODEL_HAIKU="gemini-3.6-flash-low"
MODEL_SUBAGENT="gemini-3.6-flash-medium"

# Gemini effort is encoded in the model name (gemini-3.6-flash-{low,medium,high}),
# so we leave Claude Code's --effort unset here to avoid double control.
EFFORT=""

# The proxy authenticates upstream itself; the token is a local placeholder.
AUTH_MODE="static"
AUTH_REFERENCE="local-antigravity-proxy"

# Hide raw gateway model discovery so a Claude model cannot be selected
# accidentally inside a 1M-context Gemini session.
EXTRA_ENV="CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=0"

PRE_START="antigravity_ensure_gateway"
POST_STOP="antigravity_stop_gateway"
HEALTH_CHECK_URL="$BASE_URL/health"
