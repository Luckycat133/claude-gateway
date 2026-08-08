#!/bin/sh
# Baidu Qianfan team Token Plan has its own endpoint and credential.
PROVIDER_NAME="qianfan-team"
PROVIDER_DESC="Baidu Qianfan team Token Plan"

BASE_URL="https://qianfan.baidubce.com/anthropic/tokenplan/team"
MODEL="deepseek-v3.2"
CONTEXT_TOKENS=""
MODEL_OPUS="deepseek-v3.2"
MODEL_SONNET="deepseek-v3.2"
MODEL_HAIKU="deepseek-v3.2"
MODEL_SUBAGENT="deepseek-v3.2"
EFFORT="high"

AUTH_MODE="surfaces"
PLAN_URL="https://qianfan.baidubce.com/anthropic/tokenplan/team"
PLAN_AUTH_TYPE="bearer"
PLAN_KEY_ENV="QIANFAN_TEAM_TOKEN_PLAN_KEY"
PLAN_KEYS="qianfan-team-token-plan"
PLAN_MODEL="deepseek-v3.2"

EXTRA_ENV="API_TIMEOUT_MS=600000
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
