#!/bin/sh
# Alibaba Model Studio Coding Plan is isolated from its Token Plan endpoint.
PROVIDER_NAME="dashscope-coding"
PROVIDER_DESC="Alibaba Model Studio Coding Plan"

BASE_URL="https://coding.dashscope.aliyuncs.com/apps/anthropic"
MODEL="qwen3.7-plus"
CONTEXT_TOKENS=""
MODEL_OPUS="qwen3.7-plus"
MODEL_SONNET="qwen3.7-plus"
MODEL_HAIKU="qwen3.7-plus"
MODEL_SUBAGENT="qwen3.7-plus"
EFFORT="high"

AUTH_MODE="surfaces"
PLAN_URL="https://coding.dashscope.aliyuncs.com/apps/anthropic"
PLAN_AUTH_TYPE="bearer"
PLAN_KEY_ENV="DASHSCOPE_CODING_PLAN_KEY"
PLAN_KEYS="dashscope-coding-plan"
PLAN_MODEL="qwen3.7-plus"

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
