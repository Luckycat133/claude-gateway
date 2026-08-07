#!/bin/sh
# Provider: Claude models through the local Antigravity compatibility proxy.
. "$ROOT_DIR/lib/antigravity-common.sh"

PROVIDER_NAME="antigravity-claude"
PROVIDER_DESC="Claude models via the local Antigravity proxy"

BASE_URL=$(antigravity_base_url)
MODEL="claude-sonnet-5"
CONTEXT_TOKENS="200000"

MODEL_OPUS="claude-opus-5-thinking"
MODEL_SONNET="claude-sonnet-5"
MODEL_HAIKU="claude-sonnet-5"
MODEL_SUBAGENT="claude-sonnet-5"

EFFORT="medium"

AUTH_MODE="static"
AUTH_REFERENCE="local-antigravity-proxy"

EXTRA_ENV="CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=0"

PRE_START="antigravity_ensure_gateway"
POST_STOP="antigravity_stop_gateway"
HEALTH_CHECK_URL="$BASE_URL/health"