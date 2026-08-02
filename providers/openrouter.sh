#!/bin/sh
# Provider: OpenRouter — a unified gateway that exposes an Anthropic-compatible
# Messages API. Single auth surface (your OpenRouter key). Per OpenRouter's
# Claude Code integration guide, ANTHROPIC_API_KEY must be explicitly emptied so
# it does not conflict with the OpenRouter token.
PROVIDER_NAME="openrouter"
PROVIDER_DESC="OpenRouter (unified gateway, Anthropic-compatible)"

BASE_URL="https://openrouter.ai/api/v1"
MODEL="anthropic/claude-sonnet-4"
CONTEXT_TOKENS="200000"

MODEL_OPUS="anthropic/claude-opus-4"
MODEL_SONNET="anthropic/claude-sonnet-4"
MODEL_HAIKU="anthropic/claude-haiku-4"
MODEL_SUBAGENT="anthropic/claude-sonnet-4"

EFFORT="max"

# Single auth surface: your OpenRouter API key (Bearer).
API_URL="https://openrouter.ai/api/v1"
API_AUTH_TYPE="bearer"
API_KEY_ENV="OPENROUTER_API_KEY"
API_KEY_REF="openrouter-api-key"      # optional: store the key in macOS Keychain

# OpenRouter requires ANTHROPIC_API_KEY to be empty to avoid an auth conflict.
EXTRA_ENV="ANTHROPIC_API_KEY=
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
