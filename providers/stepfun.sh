#!/bin/sh
# Step Plan and ordinary API use different Anthropic-compatible prefixes.
PROVIDER_NAME="stepfun"
PROVIDER_DESC="StepFun Step Plan and pay-as-you-go API"

BASE_URL="https://api.stepfun.com/step_plan"
MODEL="step-3.7-flash"
CONTEXT_TOKENS="262144"
MODEL_OPUS="step-3.7-flash"
MODEL_SONNET="step-3.7-flash"
MODEL_HAIKU="step-3.7-flash"
MODEL_SUBAGENT="step-3.7-flash"
MODEL_ALIASES="step-3.5-flash-2603 step-3.5-flash step-router-v1"
EFFORT="medium"

AUTH_MODE="surfaces"
PLAN_URL="https://api.stepfun.com/step_plan"
PLAN_AUTH_TYPE="bearer"
PLAN_KEY_ENV="STEPFUN_PLAN_KEY"
PLAN_KEYS="stepfun-plan"
PLAN_MODEL="step-3.7-flash"

API_URL="https://api.stepfun.com"
API_AUTH_TYPE="bearer"
API_KEY_ENV="STEPFUN_API_KEY"
API_KEYS="stepfun-api-key"
API_MODEL="step-3.7-flash"

ASSET_PROFILE="stepfun"
ASSET_PLAN_PLUGIN_DIRS="$ROOT_DIR/assets/plugins/stepfun-plan"
EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
