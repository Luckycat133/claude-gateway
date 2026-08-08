#!/bin/sh
# Provider: OpenRouter — a unified gateway that exposes an Anthropic-compatible
# Messages API. Single auth surface (your OpenRouter key). Per OpenRouter's
# Claude Code integration guide, ANTHROPIC_API_KEY must be explicitly emptied so
# it does not conflict with the OpenRouter token.
PROVIDER_NAME="openrouter"
PROVIDER_DESC="OpenRouter (unified gateway, Anthropic-compatible)"

BASE_URL="https://openrouter.ai/api"
MODEL="nvidia/nemotron-3-ultra-550b-a55b:free"
CONTEXT_TOKENS="1000000"

# Every Claude tier maps to MODEL (see lib/provider.sh). Nemotron 3 Ultra is a
# reasoning model that honors OpenRouter's `reasoning_effort` (low|medium|high);
# "high" is the maximal value valid on both the Claude Code --effort side and
# OpenRouter's side ("max"/"xhigh" are not in OpenRouter's vocabulary).

EFFORT="high"

# Single auth surface: your OpenRouter API key, sent as Authorization: Bearer.
# Env var first, macOS Keychain second — same order the old dual-source fields
# resolved in, without pretending there are two accounts to fail over between.
AUTH_MODE="env"
AUTH_REFERENCE="OPENROUTER_API_KEY"
AUTH_KEYCHAIN_FALLBACK="openrouter-api-key"
_AUTH_SCHEME="bearer"

# OpenRouter requires ANTHROPIC_API_KEY to be empty to avoid an auth conflict.
EXTRA_ENV="ANTHROPIC_API_KEY=
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
