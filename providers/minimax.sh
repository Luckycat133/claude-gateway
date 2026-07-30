# Provider: MiniMax Token Plan (China Anthropic-compatible endpoint).
PROVIDER_NAME="minimax"
PROVIDER_DESC="MiniMax M3 via the China Anthropic-compatible endpoint"

BASE_URL="https://api.minimaxi.com/anthropic"
MODEL="MiniMax-M3"
CONTEXT_TOKENS="1048576"

# All Claude model aliases map to the single MiniMax model.
MODEL_OPUS="MiniMax-M3"
MODEL_SONNET="MiniMax-M3"
MODEL_HAIKU="MiniMax-M3"
MODEL_SUBAGENT="MiniMax-M3"

# Key stored in macOS Keychain. Only the name is committed; never the value.
AUTH_MODE="keychain"
AUTH_REFERENCE="codex-minimax-token-plan"

# Extra environment, one KEY=VALUE per line.
EXTRA_ENV="API_TIMEOUT_MS=3000000
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

PRE_START=""
POST_STOP=""
HEALTH_CHECK_URL=""
