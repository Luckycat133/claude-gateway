#!/bin/sh
# Provider: Ollama — local/cloud open-weight models via Ollama's native
# Anthropic-compatible Messages API (Ollama v0.14.0+).
PROVIDER_NAME="ollama"
PROVIDER_DESC="Ollama (local/cloud open-weight models) via native Anthropic-compatible Messages API"

BASE_URL="http://localhost:11434"
MODEL="glm-4.7-flash"
CONTEXT_TOKENS="65536"

# Ollama ignores the auth token value but Claude Code requires a non-empty one.
# `none` auth mode leaves it unset, so inject a dummy token (and matching API key).
AUTH_MODE="none"
EXTRA_ENV="ANTHROPIC_AUTH_TOKEN=ollama
ANTHROPIC_API_KEY=ollama"

# Fail fast with a clear message if the Ollama service isn't up.
PRE_START='curl -fsS --max-time 3 http://localhost:11434 >/dev/null 2>&1 || die "Ollama not reachable at http://localhost:11434 — start it (ollama serve) and pull a model first"'

POST_STOP=""
HEALTH_CHECK_URL="http://localhost:11434"