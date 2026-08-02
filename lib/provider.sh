#!/bin/sh
# Provider loading. Sourced by bin/crouter after core globals are set.
# Each provider file (providers/<name>.sh) declares only "how to connect".
# Uses globals: PROVIDERS_DIR.

provider_file() { printf '%s/%s.sh' "$PROVIDERS_DIR" "$1"; }

provider_names() {
  for f in "$PROVIDERS_DIR"/*.sh; do
    [ -f "$f" ] || continue
    basename "$f" .sh
  done
}

load_provider() {
  _name=$1
  _file=$(provider_file "$_name")
  [ -f "$_file" ] || die "unknown provider '$_name' (try: crouter list)"

  # Reset the provider contract before sourcing.
  PROVIDER_NAME= PROVIDER_DESC= BASE_URL= MODEL=
  MODEL_OPUS= MODEL_SONNET= MODEL_HAIKU= MODEL_SUBAGENT=
  CONTEXT_TOKENS= AUTH_MODE=none AUTH_REFERENCE=
  EXTRA_ENV= PRE_START= POST_STOP= HEALTH_CHECK_URL=

  . "$_file"

  PROVIDER_NAME=${PROVIDER_NAME:-$_name}
  [ -n "$BASE_URL" ] || die "provider '$_name': BASE_URL is required"
  [ -n "$MODEL" ]    || die "provider '$_name': MODEL is required"
  MODEL_OPUS=${MODEL_OPUS:-$MODEL}
  MODEL_SONNET=${MODEL_SONNET:-$MODEL}
  MODEL_HAIKU=${MODEL_HAIKU:-$MODEL}
  MODEL_SUBAGENT=${MODEL_SUBAGENT:-$MODEL_HAIKU}
}
