#!/bin/sh
# Provider: ByteDance Volcengine (Doubao/Seed) — Anthropic-compatible endpoint with Coding Plan.
# Official: https://www.volcengine.com/ (Doubao Seed 1.6, Doubao 1.5, DeepSeek)
# Coding Plan: subscription for AI coding (Doubao-Seed-2.0-Code, DeepSeek, Kimi 2.5)
# Token Plan: pay-as-you-go via Volcengine ModelArk
#
# Endpoint: https://ark.ap-southeast.bytepluses.com/api/v3/messages (Anthropic-compatible)
# Or region-specific: https://ark.{region}.bytepluses.com/api/v3/messages
# Auth: Volcengine AccessKey/Secret via Bearer token (ARK_API_KEY).
# Uses keypool for Coding Plan / Token Plan keys rotation.
PROVIDER_NAME="volcengine"
PROVIDER_DESC="ByteDance Volcengine (Doubao/Seed) Coding Plan / Token Plan via Anthropic-compatible API"

BASE_URL="https://ark.cn-beijing.bytepluses.com/api/v3/messages"
MODEL="doubao-seed-2-0-code"
CONTEXT_TOKENS="200000"

# Map Claude Code tiers to Doubao/Seed models.
MODEL_OPUS="doubao-seed-2-0-code"
MODEL_SONNET="doubao-seed-2-0-code"
MODEL_HAIKU="doubao-1-5-lite"
MODEL_SUBAGENT="doubao-seed-2-0-code"

EFFORT="max"

# Key pool: Coding Plan keys first, then Token Plan keys.
# Keychain service names: volcengine-coding-1, volcengine-token-1, etc.
AUTH_MODE="keypool"
AUTH_KEYS="volcengine-coding-1 volcengine-token-1"

# Optional: region override via config.sh
# VOLCENGINE_REGION="cn-beijing"  # or ap-southeast, etc.

EXTRA_ENV="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL="https://ark.cn-beijing.bytepluses.com/api/v3/models"