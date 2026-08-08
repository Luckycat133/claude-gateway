#!/bin/sh
# Qiniu subscription and pay-as-you-go keys share an Anthropic Messages URL.
PROVIDER_NAME="qiniu"
PROVIDER_DESC="Qiniu AI multi-model subscription and API"

BASE_URL="https://api.qnaigc.com"
MODEL="deepseek/deepseek-v3.2-251201"
CONTEXT_TOKENS=""
MODEL_OPUS="deepseek/deepseek-v3.2-251201"
MODEL_SONNET="deepseek/deepseek-v3.2-251201"
MODEL_HAIKU="deepseek/deepseek-v3.2-251201"
MODEL_SUBAGENT="deepseek/deepseek-v3.2-251201"
MODEL_ALIASES="z-ai/glm-4.6 z-ai/glm-4.7 z-ai/glm-5 z-ai/glm-5.1 minimax/minimax-m2.5 minimax/minimax-m2.5-highspeed minimax/minimax-m2.7 minimax/minimax-m3 moonshotai/kimi-k2.5 moonshotai/kimi-k2.6 deepseek/deepseek-v4-pro deepseek/deepseek-v4-flash"
EFFORT="high"

AUTH_MODE="surfaces"
PLAN_URL="https://api.qnaigc.com"
PLAN_AUTH_TYPE="bearer"
PLAN_KEY_ENV="QINIU_SUBSCRIPTION_KEY"
PLAN_KEYS="qiniu-subscription"
PLAN_MODEL="deepseek/deepseek-v3.2-251201"

API_URL="https://api.qnaigc.com"
API_AUTH_TYPE="bearer"
API_KEY_ENV="QINIU_API_KEY"
API_KEYS="qiniu-api-key"
API_MODEL="deepseek/deepseek-v3.2-251201"

ASSET_PROFILE="qiniu"
EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
