#!/bin/sh
# Provider: Anthropic Claude — subscription OAuth preferred, API key fallback.
PROVIDER_NAME="anthropic"
PROVIDER_DESC="Anthropic Claude (subscription OAuth preferred, API key fallback)"

BASE_URL="https://api.anthropic.com"
MODEL="claude-sonnet-5"
CONTEXT_TOKENS="1048576"

MODEL_OPUS="claude-opus-5"
MODEL_SONNET="claude-sonnet-5"
MODEL_HAIKU="claude-haiku-4-5"
MODEL_SUBAGENT="claude-sonnet-5"

EFFORT="max"

DEFAULT_URL="https://api.anthropic.com"
DEFAULT_AUTH_TYPE="bearer"
DEFAULT_TOKEN_ENV="CLAUDE_CODE_OAUTH_TOKEN"
DEFAULT_TOKEN_ENV_FALLBACK="ANTHROPIC_AUTH_TOKEN"

API_URL="https://api.anthropic.com"
API_AUTH_TYPE="x-api-key"
API_KEY_ENV="ANTHROPIC_API_KEY"
API_KEY_REF="anthropic-api-key"

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
