#!/bin/sh
# SiliconFlow exposes a pay-as-you-go Anthropic Messages endpoint.
PROVIDER_NAME="siliconflow"
PROVIDER_DESC="SiliconFlow multi-model API"

BASE_URL="https://api.siliconflow.cn"
MODEL="Pro/moonshotai/Kimi-K2.6"
CONTEXT_TOKENS=""
MODEL_OPUS="Pro/moonshotai/Kimi-K2.6"
MODEL_SONNET="Pro/moonshotai/Kimi-K2.6"
MODEL_HAIKU="Pro/moonshotai/Kimi-K2.6"
MODEL_SUBAGENT="Pro/moonshotai/Kimi-K2.6"
MODEL_ALIASES="Pro/zai-org/GLM-4.7 deepseek-ai/DeepSeek-V3.2 Pro/deepseek-ai/DeepSeek-V3.2"
EFFORT="high"

AUTH_MODE="surfaces"
API_URL="https://api.siliconflow.cn"
API_AUTH_TYPE="bearer"
API_KEY_ENV="SILICONFLOW_API_KEY"
API_KEYS="siliconflow-api-key"
API_MODEL="Pro/moonshotai/Kimi-K2.6"

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
