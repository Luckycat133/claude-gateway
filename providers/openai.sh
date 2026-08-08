#!/bin/sh
# Provider: OpenAI — GPT via official Anthropic-compatible Messages API.
# Endpoint prefix: https://api.openai.com — Claude Code appends /v1/messages.
# Auth: OpenAI API key sent as Authorization: Bearer <key>.
PROVIDER_NAME="openai"
PROVIDER_DESC="OpenAI GPT via official Anthropic-compatible Messages API"

BASE_URL="https://api.openai.com"
MODEL="gpt-5.6-terra"
CONTEXT_TOKENS="1050000"

MODEL_OPUS="gpt-5.6-sol"
MODEL_SONNET="gpt-5.6-terra"
MODEL_HAIKU="gpt-5.6-luna"
MODEL_SUBAGENT="gpt-5.6-luna"

EFFORT="high"

AUTH_MODE="keychain"
AUTH_REFERENCE="openai-api-key"
_AUTH_SCHEME="bearer"

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
