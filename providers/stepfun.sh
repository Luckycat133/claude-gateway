#!/bin/sh
# Provider: StepFun — Anthropic-compatible endpoint with Token Plan.
# Official: https://platform.stepfun.com/ (step-3.5-flash, step-router, etc.)
# Token Plan: pay-as-you-go via api.stepfun.com
# StepFun offers step-3.5-flash (coding), step-router (routing), step-audio (ASR/TTS).
#
# Endpoint: https://api.stepfun.com/v1/messages (Anthropic-compatible Messages API)
# Auth: API key as Bearer token.
# Uses keypool for Token Plan keys rotation.
PROVIDER_NAME="stepfun"
PROVIDER_DESC="StepFun (Token Plan) via native Anthropic-compatible API"

BASE_URL="https://api.stepfun.com/v1/messages"
MODEL="step-3.5-flash"
CONTEXT_TOKENS="200000"

# Map Claude Code tiers to StepFun models.
MODEL_OPUS="step-3.5-flash"
MODEL_SONNET="step-3.5-flash"
MODEL_HAIKU="step-3.5-flash"
MODEL_SUBAGENT="step-3.5-flash"

EFFORT="max"

# Key pool for Token Plan keys.
AUTH_MODE="keypool"
AUTH_KEYS="stepfun-token-1"

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL="https://api.stepfun.com/v1/models"