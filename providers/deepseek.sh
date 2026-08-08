#!/bin/sh
# Provider: DeepSeek V4 via the official Anthropic-compatible endpoint.
PROVIDER_NAME="deepseek"
PROVIDER_DESC="DeepSeek V4 (Flash/Pro) via api.deepseek.com/anthropic"

BASE_URL="https://api.deepseek.com/anthropic"
MODEL="deepseek-v4-flash"
CONTEXT_TOKENS="1000000"

MODEL_OPUS="deepseek-v4-pro"
MODEL_SONNET="deepseek-v4-flash"
MODEL_HAIKU="deepseek-v4-flash"
MODEL_SUBAGENT="deepseek-v4-flash"

EFFORT="max"

AUTH_MODE="keychain"
AUTH_REFERENCE="deepseek-api-key"

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
