#!/bin/sh
# ChatGPT/Codex subscription through the local icebear proxy.
PROVIDER_NAME="codex"
PROVIDER_DESC="ChatGPT/Codex subscription via icebear0828/codex-proxy"

BASE_URL="http://localhost:19000"
MODEL="gpt-5.6-sol"
CONTEXT_TOKENS="1050000"

MODEL_OPUS="gpt-5.6-sol"
MODEL_SONNET="gpt-5.6-terra"
MODEL_HAIKU="gpt-5.6-luna"
MODEL_SUBAGENT="gpt-5.6-luna"

EFFORT=""

# The proxy uses this dummy token while handling subscription auth itself.
AUTH_MODE="none"
EXTRA_ENV="ANTHROPIC_AUTH_TOKEN=pwd
ANTHROPIC_API_KEY=pwd"

PRE_START='curl -fsS --max-time 3 http://localhost:19000/health >/dev/null 2>&1 || die "icebear0828/codex-proxy not running at http://localhost:19000/health: start with docker compose up -d (--port 19000) or run .dmg and complete ChatGPT login"'
POST_STOP=""
HEALTH_CHECK_URL="http://localhost:19000/health"
