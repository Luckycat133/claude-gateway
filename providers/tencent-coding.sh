#!/bin/sh
# Tencent Coding Plan has a dedicated endpoint and credential.
PROVIDER_NAME="tencent-coding"
PROVIDER_DESC="Tencent Cloud Coding Plan"

BASE_URL="https://api.lkeap.cloud.tencent.com/coding/anthropic"
MODEL="tc-code-latest"
CONTEXT_TOKENS=""
MODEL_OPUS="tc-code-latest"
MODEL_SONNET="tc-code-latest"
MODEL_HAIKU="tc-code-latest"
MODEL_SUBAGENT="tc-code-latest"
EFFORT="high"

AUTH_MODE="surfaces"
PLAN_URL="https://api.lkeap.cloud.tencent.com/coding/anthropic"
PLAN_AUTH_TYPE="bearer"
PLAN_KEY_ENV="TENCENT_CODING_PLAN_KEY"
PLAN_KEYS="tencent-coding-plan"
PLAN_MODEL="tc-code-latest"

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
