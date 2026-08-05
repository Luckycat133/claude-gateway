#!/bin/sh
# Provider: OpenAI GPT-5 via OpenAI's official Anthropic-compatible Messages API.
# Endpoint: https://api.openai.com/v1/messages — OpenAI's own /v1/messages
# compatibility layer (added 2025) so Claude Code / Agents SDK talk to GPT models
# natively; no translation proxy required.
#
# Auth: OpenAI API key sent as `Authorization: Bearer <key>` — OpenAI's compat
# endpoint does NOT use Anthropic's `x-api-key` header shape. The
# `anthropic-version` header is sent by Claude Code automatically.
#
# Models (official catalog, 2026-07-09+): the GPT-5.6 family — gpt-5.6-sol
# (frontier), gpt-5.6-terra (balanced, production default), gpt-5.6-luna
# (efficient). All 1.05M ctx / 128K max output; `gpt-5.6` aliases to sol.
# OpenAI recommends pinning explicit tier ids instead of the family alias.
PROVIDER_NAME="openai"
PROVIDER_DESC="OpenAI GPT-5.6 via official Anthropic-compatible Messages API"

BASE_URL="https://api.openai.com/v1/messages"
MODEL="gpt-5.6-terra"
CONTEXT_TOKENS="1050000"          # gpt-5.6 family: 1.05M ctx

# Map Claude Code's model tiers to OpenAI models.
MODEL_OPUS="gpt-5.6-sol"
MODEL_SONNET="gpt-5.6-terra"
MODEL_HAIKU="gpt-5.6-luna"
MODEL_SUBAGENT="gpt-5.6-luna"

# Reasoning effort passed to Claude Code via --effort (low|medium|high|xhigh|max).
# OpenAI's compat endpoint maps Anthropic thinking budget_tokens to its own
# reasoning effort (low/medium/high; xhigh/max are clamped by the backend).
EFFORT="high"

# API key lives in macOS Keychain (service name below). Value is never committed.
AUTH_MODE="keychain"
AUTH_REFERENCE="openai-api-key"

# OpenAI's compat endpoint expects Bearer auth; do NOT send x-api-key.
# Setting _AUTH_SCHEME=bearer makes lib/launch.sh:70-78 take the bearer-only
# branch and keeps `crouter openai` from sending both Authorization and
# x-api-key headers at once.
_AUTH_SCHEME="bearer"

# Cut non-essential traffic for a snappier session.
EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
