#!/bin/sh
# Provider: Anthropic Claude — preferred "default account" (subscription OAuth)
# first, API key fallback. Claude Code's subscription (Pro/Max) OAuth token is
# used preferentially (it draws from your plan's included usage); on 401/429
# the unified gateway (`crouter all`) transparently fails over to ANTHROPIC_API_KEY.
#
# The "default account" is the Claude subscription OAuth token. Generate a
# long-lived one with `claude setup-token` and export it as CLAUDE_CODE_OAUTH_TOKEN
# (or reuse ANTHROPIC_AUTH_TOKEN). This is zero-config once you've logged in.
PROVIDER_NAME="anthropic"
PROVIDER_DESC="Anthropic Claude (subscription OAuth preferred, API key fallback)"

BASE_URL="https://api.anthropic.com"
MODEL="claude-sonnet-4"
CONTEXT_TOKENS="200000"

# Map Claude Code's model tiers to Claude models (adjust to your plan's access).
MODEL_OPUS="claude-opus-4-5"
MODEL_SONNET="claude-sonnet-4"
MODEL_HAIKU="claude-haiku-4"
MODEL_SUBAGENT="claude-sonnet-4"

EFFORT="max"

# --- Preferred "default account" (subscription OAuth) — tried FIRST ---------
DEFAULT_URL="https://api.anthropic.com"
DEFAULT_AUTH_TYPE="bearer"            # sent as Authorization: Bearer
DEFAULT_TOKEN_ENV="CLAUDE_CODE_OAUTH_TOKEN"
DEFAULT_TOKEN_ENV_FALLBACK="ANTHROPIC_AUTH_TOKEN"

# --- Fallback API surface (Anthropic Console API key) -----------------------
API_URL="https://api.anthropic.com"
API_AUTH_TYPE="x-api-key"             # sent as x-api-key
API_KEY_ENV="ANTHROPIC_API_KEY"
API_KEY_REF="anthropic-api-key"       # optional: store the key in macOS Keychain

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
