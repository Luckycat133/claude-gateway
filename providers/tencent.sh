#!/bin/sh
# Tencent personal Token Plan and TokenHub pay-as-you-go are isolated surfaces.
PROVIDER_NAME="tencent"
PROVIDER_DESC="Tencent Cloud Token Plan and TokenHub API"

BASE_URL="https://api.lkeap.cloud.tencent.com/plan/anthropic"
MODEL="tc-code-latest"
CONTEXT_TOKENS=""
MODEL_OPUS="tc-code-latest"
MODEL_SONNET="tc-code-latest"
MODEL_HAIKU="tc-code-latest"
MODEL_SUBAGENT="tc-code-latest"
MODEL_ALIASES="glm-5.2 glm-5.1 glm-5 minimax-m2.7 deepseek-v4-flash-202605 deepseek-v4-pro-202606 hy3"
EFFORT="high"

AUTH_MODE="surfaces"
PLAN_URL="https://api.lkeap.cloud.tencent.com/plan/anthropic"
PLAN_AUTH_TYPE="bearer"
PLAN_KEY_ENV="TENCENT_TOKEN_PLAN_KEY"
PLAN_KEYS="tencent-token-plan"
PLAN_MODEL="tc-code-latest"

API_URL="https://tokenhub.tencentmaas.com"
API_AUTH_TYPE="bearer"
API_KEY_ENV="TENCENT_API_KEY"
API_KEYS="tencent-api-key"
API_MODEL="hy3"

ASSET_PROFILE="tencent"
EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
ENABLE_TOOL_SEARCH=false"
PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
