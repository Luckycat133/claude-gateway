#!/bin/sh
# Provider: OpenAI GPT via the Anthropic-compatible Messages API. Preferred
# "default account" is an OPTIONAL configurable gateway (e.g. an org proxy with
# pooled quota); the official API key is the fallback. Leave OPENAI_DEFAULT_URL
# / OPENAI_DEFAULT_TOKEN unset to skip straight to the API key.
#
# Endpoint: https://api.openai.com/v1/messages  (OpenAI's Anthropic-compatible
# Messages API, added in 2025 so Claude Code / Agents SDK can use GPT models).
# It expects the `anthropic-version` header (Claude Code sends it automatically)
# and a Bearer API key. Verify your OPENAI_API_KEY has access before relying on it.
PROVIDER_NAME="openai"
PROVIDER_DESC="OpenAI GPT via Anthropic-compatible Messages API"

BASE_URL="https://api.openai.com/v1/messages"
MODEL="gpt-4o"
CONTEXT_TOKENS="128000"

MODEL_OPUS="gpt-4o"
MODEL_SONNET="gpt-4o"
MODEL_HAIKU="gpt-4o-mini"
MODEL_SUBAGENT="gpt-4o"

EFFORT=""

# --- Preferred "default account" (OPTIONAL gateway) — tried FIRST ----------
DEFAULT_URL="${OPENAI_DEFAULT_URL:-}"
DEFAULT_AUTH_TYPE="bearer"
DEFAULT_TOKEN_ENV="OPENAI_DEFAULT_TOKEN"

# --- Fallback API surface (official OpenAI API key) -------------------------
API_URL="https://api.openai.com/v1/messages"
API_AUTH_TYPE="bearer"                # OpenAI API key is a Bearer token
API_KEY_ENV="OPENAI_API_KEY"
API_KEY_REF="openai-api-key"          # optional: store the key in macOS Keychain

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
