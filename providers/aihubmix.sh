#!/bin/sh
# AIHubMix exposes its multi-model catalog through Anthropic Messages.
PROVIDER_NAME="aihubmix"
PROVIDER_DESC="AIHubMix multi-model API"

BASE_URL="https://aihubmix.com"
MODEL="coding-glm-5.1-free"
CONTEXT_TOKENS=""
MODEL_OPUS="coding-glm-5.1-free"
MODEL_SONNET="coding-glm-5.1-free"
MODEL_HAIKU="coding-glm-5.1-free"
MODEL_SUBAGENT="coding-glm-5.1-free"
MODEL_ALIASES="kimi-for-coding-free gpt-4.1-free xiaomi-mimo-v2-pro-free"
EFFORT=""

AUTH_MODE="surfaces"
API_URL="https://aihubmix.com"
API_AUTH_TYPE="bearer"
API_KEY_ENV="AIHUBMIX_API_KEY"
API_KEYS="aihubmix-api-key"
API_MODEL="coding-glm-5.1-free"

ASSET_PROFILE="aihubmix"
EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
