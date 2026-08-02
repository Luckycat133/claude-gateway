#!/bin/sh
# Provider: Ollama — local / cloud open-weight models via Ollama's native
# Anthropic-compatible Messages API (Ollama v0.14.0+).
#
# Ollama serves the Anthropic /v1/messages protocol on its default port, so
# Claude Code can talk to it with NO translation proxy. Auth is a dummy
# non-empty token that Ollama ignores; the `none` auth mode leaves
# ANTHROPIC_AUTH_TOKEN unset, so we inject the dummy value via EXTRA_ENV.
#
# Setup (one-time):
#   ollama pull glm-4.7-flash            # or qwen3-coder / gpt-oss:20b / a :cloud model
#   # Ollama runs as a service on :11434 by default; PRE_START below verifies it.
#
# Per-session model override (Claude Code internally requests opus/sonnet/haiku
# tiers — map them to whatever you have pulled):
#   crouter ollama --model glm-4.7-flash
# or alias a local model to a tier name so the defaults below "just work":
#   ollama cp glm-4.7-flash claude-3-5-sonnet
PROVIDER_NAME="ollama"
PROVIDER_DESC="Ollama (local/cloud open-weight models) via its native Anthropic-compatible API"

BASE_URL="http://localhost:11434"
MODEL="glm-4.7-flash"
CONTEXT_TOKENS="65536"

# All Claude tiers map to the single default model unless overridden per session
# or aliased with `ollama cp`. Adjust to whatever you have pulled locally.
MODEL_OPUS="glm-4.7-flash"
MODEL_SONNET="glm-4.7-flash"
MODEL_HAIKU="glm-4.7-flash"
MODEL_SUBAGENT="glm-4.7-flash"

# Ollama ignores the auth token value but Claude Code requires a non-empty one.
# `none` auth mode leaves it unset, so inject the dummy token (and a matching
# dummy API key) here.
AUTH_MODE="none"
EXTRA_ENV="ANTHROPIC_AUTH_TOKEN=ollama
ANTHROPIC_API_KEY=ollama"

# Ollama needs a large context window for agentic Claude Code; 64K is a safe
# floor. Bump per your VRAM/model (set num_ctx in a Modelfile or
# OLLAMA_CONTEXT_LENGTH before serving).
#
# Optional reasoning effort for thinking-capable models (qwen3-coder,
# glm-4.7-flash, ...). Leave empty if your model lacks extended thinking — Claude
# Code would otherwise request thinking it cannot satisfy.
# EFFORT="medium"

# Fail fast with a clear message if the Ollama service isn't up.
PRE_START='curl -fsS --max-time 3 http://localhost:11434 >/dev/null 2>&1 || die "Ollama not reachable at http://localhost:11434 — start it (ollama serve) and pull a model first"'

POST_STOP=""
HEALTH_CHECK_URL="http://localhost:11434"
