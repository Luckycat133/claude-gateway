#!/bin/sh
# Provider: DeepSeek V4 via the official Anthropic-compatible endpoint.
# DeepSeek exposes both an OpenAI-compatible (https://api.deepseek.com) and an
# Anthropic-compatible (https://api.deepseek.com/anthropic) endpoint. We use the
# latter so Claude Code talks to it natively -- no translation proxy required.
#
# Model names changed on 2026-07-24: the old `deepseek-chat` / `deepseek-reasoner`
# are deprecated; use `deepseek-v4-flash` (fast/cheap, 1M ctx) and
# `deepseek-v4-pro` (strong, 1M ctx) instead.
PROVIDER_NAME="deepseek"
PROVIDER_DESC="DeepSeek V4 (Flash/Pro) via api.deepseek.com/anthropic"

BASE_URL="https://api.deepseek.com/anthropic"
MODEL="deepseek-v4-flash"
CONTEXT_TOKENS="1000000"

# Map Claude Code's model tiers to DeepSeek models.
MODEL_OPUS="deepseek-v4-pro"
MODEL_SONNET="deepseek-v4-flash"
MODEL_HAIKU="deepseek-v4-flash"
MODEL_SUBAGENT="deepseek-v4-flash"

# Reasoning effort passed to Claude Code via --effort (low|medium|high|xhigh|max).
# Effect depends on whether DeepSeek's /anthropic endpoint honors the thinking config.
EFFORT="medium"

# API key lives in macOS Keychain (service name below). Value is never committed.
AUTH_MODE="keychain"
AUTH_REFERENCE="deepseek-api-key"

# Cut non-essential traffic for a snappier session.
EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
