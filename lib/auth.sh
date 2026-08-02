#!/bin/sh
# Auth resolution, health checks, and the keypool proxy launcher.
# Sourced by bin/crouter. Functions only read these globals at call time:
# AUTH_MODE, AUTH_REFERENCE, PLUS_URL, PLUS_KEYS, AUTH_KEYS, BASE_URL, USER,
# PROVIDER_NAME, BIN_DIR, NODE_BIN, LOG_DIR, ROOT_DIR.

# ---------------------------------------------------------------------------
# Auth. The secret only ever lives in AUTH_TOKEN inside this process.
# ---------------------------------------------------------------------------
# Keychain availability cache (disk-backed): avoids repeating `security` lookups.
_kc_cache_dir() { printf '%s/.kc-cache' "${LOG_DIR:-$ROOT_DIR/logs}"; }
_kc_state() {
  _d=$(_kc_cache_dir)
  _f="$_d/$1"
  [ -f "$_f" ] && cat "$_f" 2>/dev/null
  return 0
}
_kc_set_state() {
  mkdir -p "$(_kc_cache_dir)" 2>/dev/null
  printf '%s' "$2" > "$(_kc_cache_dir)/$1" 2>/dev/null
}

resolve_auth() {
  AUTH_TOKEN=
  case $AUTH_MODE in
    keychain)
      AUTH_TOKEN=$(security find-generic-password -a "$USER" -s "$AUTH_REFERENCE" -w 2>/dev/null)
      [ -n "$AUTH_TOKEN" ] || die "keychain item '$AUTH_REFERENCE' not found (provider '$PROVIDER_NAME')"
      ;;
    env)
      AUTH_TOKEN=$(printenv "$AUTH_REFERENCE" 2>/dev/null)
      [ -n "$AUTH_TOKEN" ] || die "environment variable '$AUTH_REFERENCE' is empty (provider '$PROVIDER_NAME')"
      ;;
    command)
      AUTH_TOKEN=$(eval "$AUTH_REFERENCE") ||
        die "auth command failed (provider '$PROVIDER_NAME')"
      [ -n "$AUTH_TOKEN" ] || die "auth command returned empty output (provider '$PROVIDER_NAME')"
      ;;
    static)
      AUTH_TOKEN=$AUTH_REFERENCE
      ;;
    none)
      ;;
    *)
      die "provider '$PROVIDER_NAME': unsupported AUTH_MODE '$AUTH_MODE'"
      ;;
  esac
}

# keypool: resolve a pool of keys from keychain, start a local key-failover proxy,
# and expose its URL. Claude Code then talks to the proxy, which rotates keys on
# 429/401 so quota exhaustion is handled transparently (mid-session).
#
# Plus-endpoint ordering: when PLUS_URL + PLUS_KEYS are configured, the plus
# keys and plus URL are placed FIRST in the proxy's attempt list. All keys share
# the same upstream account quota — the plus endpoint is just a different
# URL on the same account (e.g. Coding Plan vs Token Plan). Each key is tried
# against every declared target in order; the proxy does not treat surfaces
# as exclusive.
start_keypool() {
  [ -n "$NODE_BIN" ] || die "node not found; keypool proxy cannot start"
  [ -n "${AUTH_KEYS:-}" ] || die "provider '$PROVIDER_NAME': AUTH_MODE=keypool requires AUTH_KEYS"

  _plus_pool=""
  if [ -n "${PLUS_URL:-}" ] && [ -n "${PLUS_KEYS:-}" ]; then
    for _ref in $PLUS_KEYS; do
      _t=$(security find-generic-password -a "$USER" -s "$_ref" -w 2>/dev/null)
      [ -n "$_t" ] || die "keychain item '$_ref' not found (provider '$PROVIDER_NAME')"
      _plus_pool="$_plus_pool $_t"
    done
    _plus_pool=$(echo "$_plus_pool" | sed 's/^ *//; s/ *$//')
  fi

  _main_pool=""
  for _ref in $AUTH_KEYS; do
    _t=$(security find-generic-password -a "$USER" -s "$_ref" -w 2>/dev/null)
    [ -n "$_t" ] || die "keychain item '$_ref' not found (provider '$PROVIDER_NAME')"
    _main_pool="$_main_pool $_t"
  done
  _main_pool=$(echo "$_main_pool" | sed 's/^ *//; s/ *$//')

  # Plus first: plus keys, then main keys. Plus URL first, then main URL.
  if [ -n "$_plus_pool" ]; then
    _pool="$_plus_pool $_main_pool"
    _targets="$PLUS_URL;$BASE_URL"
  else
    _pool="$_main_pool"
    _targets="$BASE_URL"
  fi

  _out=$(mktemp -t keypool.XXXXXX)
  KEYPOOL_KEYS="$_pool" KEYPOOL_TARGETS="$_targets" KEYPOOL_PORT=0 \
    "$NODE_BIN" "$BIN_DIR/keypool-proxy" > "$_out" 2>/dev/null &
  KEYPOOL_PID=$!

  _lp=""
  _i=0
  while [ $_i -lt 30 ]; do
    _lp=$(grep -m1 '^KEYPOOL_LISTENING_PORT=' "$_out" 2>/dev/null | cut -d= -f2)
    [ -n "$_lp" ] && break
    sleep 0.1
    _i=$((_i + 1))
  done
  rm -f "$_out"
  if [ -z "$_lp" ]; then
    kill "$KEYPOOL_PID" 2>/dev/null
    die "keypool proxy failed to start (provider '$PROVIDER_NAME')"
  fi
  KEYPOOL_URL="http://127.0.0.1:$_lp"
  export KEYPOOL_URL KEYPOOL_PID
  _nkeys=$(echo "$_pool" | wc -w | tr -d ' ')
  _ntargets=$(echo "$_targets" | tr ';' '\n' | wc -l | tr -d ' ')
  _note=""
  if [ "$_ntargets" -gt 1 ]; then
    _note=" (plus-first: $_ntargets endpoints, $_nkeys keys)"
  else
    _note=" ($_nkeys keys, 1 endpoint)"
  fi
  info "keypool: proxy on $KEYPOOL_URL$_note"
}

# Non-destructive availability check used by status/doctor (never prints secrets).
check_auth() {
  case $AUTH_MODE in
    keychain)
      _st=$(_kc_state "$AUTH_REFERENCE")
      if [ -z "$_st" ]; then
        if security find-generic-password -a "$USER" -s "$AUTH_REFERENCE" >/dev/null 2>&1; then
          _st=ok
        else
          _st=missing
        fi
        _kc_set_state "$AUTH_REFERENCE" "$_st"
      fi
      [ "$_st" = ok ]
      ;;
    env)
      _v=$(printenv "$AUTH_REFERENCE" 2>/dev/null); [ -n "$_v" ] ;;
    command)
      _v=$(eval "$AUTH_REFERENCE" 2>/dev/null) && [ -n "$_v" ] ;;
    static|none)
      true ;;
    keypool)
      _ok=0
      for _ref in ${AUTH_KEYS:-}; do
        if security find-generic-password -a "$USER" -s "$_ref" >/dev/null 2>&1; then _ok=1; break; fi
      done
      [ "$_ok" -eq 1 ] ;;
    *)
      false ;;
  esac
}

check_health() {
  [ -n "$HEALTH_CHECK_URL" ] || return 2
  curl -fsS --max-time 3 "$HEALTH_CHECK_URL" >/dev/null 2>&1
}
