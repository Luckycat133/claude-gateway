#!/bin/sh
# InfiniAI GenStudio exposes a pay-as-you-go Anthropic Messages endpoint.
PROVIDER_NAME="infini"
PROVIDER_DESC="InfiniAI GenStudio API"

BASE_URL="https://cloud.infini-ai.com/maas"
MODEL="glm-5.1"
CONTEXT_TOKENS=""
MODEL_OPUS="glm-5.1"
MODEL_SONNET="glm-5.1"
MODEL_HAIKU="glm-5.1"
MODEL_SUBAGENT="glm-5.1"
EFFORT=""

AUTH_MODE="surfaces"
API_URL="https://cloud.infini-ai.com/maas"
API_AUTH_TYPE="bearer"
API_KEY_ENV="INFINI_API_KEY"
API_KEYS="infini-api-key"
API_MODEL="glm-5.1"

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
