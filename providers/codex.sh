#!/bin/sh
# Provider: Codex via icebear0828/codex-proxy (ChatGPT/Codex subscription).
# icebear proxy exposes /v1/messages on :19000 with Anthropic-compatible API.
# Subscription auth handled by icebear OAuth PKCE; crouter injects dummy token.
PROVIDER_NAME="codex"
PROVIDER_DESC="ChatGPT/Codex subscription via icebear0828/codex-proxy"

BASE_URL="http://localhost:19000"
MODEL="gpt-5.6-terra"
CONTEXT_TOKENS="1050000"

MODEL_OPUS="gpt-5.6-terra"
MODEL_SONNET="gpt-5.6-terra"
MODEL_HAIKU="gpt-5.6-terra"
MODEL_SUBAGENT="gpt-5.6-terra"

EFFORT=""

# icebear auto-generates proxy_api_key=pwd on first run; inject matching
# dummy token so Claude Code sees non-empty credentials.
AUTH_MODE="none"
EXTRA_ENV="ANTHROPIC_AUTH_TOKEN=pwd
ANTHROPIC_API_KEY=pwd"

PRE_START='curl -fsS --max-time 3 http://localhost:19000/health >/dev/null 2>&1 || die "icebear0828/codex-proxy not running at http://localhost:19000/health — start with docker compose up -d (--port 19000) or run .dmg and complete ChatGPT login"'
POST_STOP=""
HEALTH_CHECK_URL="http://localhost:19000/health"