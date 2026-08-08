#!/bin/sh
# PPIO exposes a pay-as-you-go Anthropic Messages endpoint and OAuth MCP.
PROVIDER_NAME="ppio"
PROVIDER_DESC="PPIO multi-model API"

BASE_URL="https://api.ppio.com/anthropic"
MODEL="minimax/minimax-m3"
CONTEXT_TOKENS="1000000"
MODEL_OPUS="minimax/minimax-m3"
MODEL_SONNET="minimax/minimax-m3"
MODEL_HAIKU="minimax/minimax-m3"
MODEL_SUBAGENT="minimax/minimax-m3"
MODEL_ALIASES="zai-org/glm-5.2"
EFFORT=""

AUTH_MODE="surfaces"
API_URL="https://api.ppio.com/anthropic"
API_AUTH_TYPE="bearer"
API_KEY_ENV="PPIO_API_KEY"
API_KEYS="ppio-api-key"
API_MODEL="minimax/minimax-m3"

ASSET_PROFILE="ppio"
EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
