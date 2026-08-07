#!/bin/sh
# Provider: Baichuan — Anthropic-compatible endpoint with Token Plan.
# Official: https://platform.baichuan-ai.com/ (Baichuan-M3-Plus, Baichuan-M3)
# Token Plan: pay-as-you-go via api.baichuan-ai.com
# Note: Baichuan uses OpenAI-compatible format; requires proxy for Anthropic.
# For native Anthropic, use a compatible proxy or check if they added support.
#
# Endpoint: https://api.baichuan-ai.com/v1/messages (if Anthropic-compatible)
# Auth: API key as Bearer token.
# Uses keypool for Token Plan keys rotation.
PROVIDER_NAME="baichuan"
PROVIDER_DESC="Baichuan (Token Plan) via Anthropic-compatible API"

BASE_URL="https://api.baichuan-ai.com/v1/messages"
MODEL="baichuan-m3-plus"
CONTEXT_TOKENS="200000"

# Map Claude Code tiers to Baichuan models.
MODEL_OPUS="baichuan-m3-plus"
MODEL_SONNET="baichuan-m3-plus"
MODEL_HAIKU="baichuan-m3"
MODEL_SUBAGENT="baichuan-m3"

EFFORT="max"

# Key pool for Token Plan keys.
AUTH_MODE="keypool"
AUTH_KEYS="baichuan-token-1"

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL="https://api.baichuan-ai.com/v1/models"