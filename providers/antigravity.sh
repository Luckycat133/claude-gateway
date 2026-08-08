#!/bin/sh
# Provider: Gemini models through the local Antigravity compatibility proxy.
. "$ROOT_DIR/lib/antigravity-common.sh"

PROVIDER_NAME="antigravity"
PROVIDER_DESC="Gemini models via the local Antigravity proxy"

BASE_URL=$(antigravity_base_url)
MODEL="gemini-3.1-pro-low"
CONTEXT_TOKENS="1048576"

MODEL_OPUS="gemini-3.1-pro-low"
MODEL_SONNET="gemini-3.5-flash-low"
MODEL_HAIKU="gemini-3.5-flash-low"
MODEL_SUBAGENT="gemini-3.5-flash-low"

MODEL_ALIASES="gemini-3.1-pro-high gemini-3-flash"

# Gemini effort is encoded in the model name.
EFFORT=""

AUTH_MODE="static"
AUTH_REFERENCE="local-antigravity-proxy"

EXTRA_ENV="CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=0"

PRE_START="antigravity_ensure_gateway"
POST_STOP="antigravity_stop_gateway"
HEALTH_CHECK_URL="$BASE_URL/health"
