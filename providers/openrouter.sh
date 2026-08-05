#!/bin/sh
# Provider: OpenRouter — a unified gateway that exposes an Anthropic-compatible
# Messages API. Single auth surface (your OpenRouter key). Per OpenRouter's
# Claude Code integration guide, ANTHROPIC_API_KEY must be explicitly emptied so
# it does not conflict with the OpenRouter token.
PROVIDER_NAME="openrouter"
PROVIDER_DESC="OpenRouter (unified gateway, Anthropic-compatible)"

BASE_URL="https://openrouter.ai/api"
MODEL="nvidia/nemotron-3-ultra-550b-a55b:free"
CONTEXT_TOKENS="200000"

MODEL_OPUS="nvidia/nemotron-3-ultra-550b-a55b:free"
MODEL_SONNET="nvidia/nemotron-3-ultra-550b-a55b:free"
MODEL_HAIKU="nvidia/nemotron-3-ultra-550b-a55b:free"
MODEL_SUBAGENT="nvidia/nemotron-3-ultra-550b-a55b:free"

EFFORT="max"

# Single auth surface: your OpenRouter API key (Bearer).
API_URL="https://openrouter.ai/api"
API_AUTH_TYPE="bearer"
API_KEY_ENV="OPENROUTER_API_KEY"
API_KEY_REF="openrouter-api-key"      # optional: store the key in macOS Keychain

# OpenRouter requires ANTHROPIC_API_KEY to be empty to avoid an auth conflict.
EXTRA_ENV="ANTHROPIC_API_KEY=
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
