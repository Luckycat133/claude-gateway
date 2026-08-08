#!/bin/sh
# DeepSeek's official Anthropic-compatible pay-as-you-go API.
PROVIDER_NAME="deepseek"
PROVIDER_DESC="DeepSeek V4 Flash/Pro API"

BASE_URL="https://api.deepseek.com/anthropic"
MODEL="deepseek-v4-flash"
CONTEXT_TOKENS="1000000"
MODEL_OPUS="deepseek-v4-pro"
MODEL_SONNET="deepseek-v4-flash"
MODEL_HAIKU="deepseek-v4-flash"
MODEL_SUBAGENT="deepseek-v4-flash"
EFFORT="max"

AUTH_MODE="surfaces"
API_URL="https://api.deepseek.com/anthropic"
API_AUTH_TYPE="x-api-key"
API_KEY_ENV="DEEPSEEK_API_KEY"
API_KEYS="deepseek-api-key"
API_MODEL="deepseek-v4-flash"
API_MODEL_OPUS="deepseek-v4-pro"
API_MODEL_SONNET="deepseek-v4-flash"
API_MODEL_HAIKU="deepseek-v4-flash"
API_MODEL_SUBAGENT="deepseek-v4-flash"

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
