#!/bin/sh
# Provider: Alibaba Cloud Model Studio (DashScope) — Qwen via native
# Anthropic-compatible Messages API. Official docs use -latest for current version.
PROVIDER_NAME="dashscope"
PROVIDER_DESC="Alibaba Cloud Model Studio (DashScope) Qwen via native Anthropic-compatible Messages API"

BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1/messages"
MODEL="qwen-plus-latest"
CONTEXT_TOKENS="32768"

MODEL_OPUS="qwen-max-latest"
MODEL_SONNET="qwen-plus-latest"
MODEL_HAIKU="qwen-turbo-latest"
MODEL_SUBAGENT="qwen-turbo-latest"

EFFORT="medium"

AUTH_MODE="keychain"
AUTH_REFERENCE="dashscope-api-key"
_AUTH_SCHEME="bearer"

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL="https://dashscope.aliyuncs.com/compatible-mode/v1/models"