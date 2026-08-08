#!/bin/sh
# Key management for pooled providers. Explicit surface providers edit
# PLAN_KEYS/API_KEYS; legacy keypools retain AUTH_KEYS/PLUS_KEYS.
# Never prints the secret value.
# Depends on: provider.sh (provider_file, load_provider).

# _surface_var <name>   ->  variable name holding the keys for that surface.
# Public surfaces are plan/api. main/plus remain compatibility aliases.
_surface_var() {
  case $1 in
    plan|token-plan) printf 'PLAN_KEYS' ;;
    api|api-key)     printf 'API_KEYS' ;;
    main)
      if [ "${AUTH_MODE:-}" = surfaces ]; then printf 'API_KEYS'; else printf 'AUTH_KEYS'; fi
      ;;
    plus)
      if [ "${AUTH_MODE:-}" = surfaces ]; then printf 'PLAN_KEYS'; else printf 'PLUS_KEYS'; fi
      ;;
    *) die "unknown surface '$1' (expected: plan or api)" ;;
  esac
}

_validate_service_name() {
  case $1 in
    ''|.|..|*[!A-Za-z0-9._:@+-]*)
      die "invalid Keychain service name '$1' (use letters, digits, dot, underscore, colon, at, plus, or hyphen)" ;;
  esac
}

# _read_kv <file> <var>   ->  print current value of VAR="..." in file (no quotes, no comments)
_read_kv() {
  awk -v v="$2" '
    $0 ~ "^"v"=" {
      sub("^"v"=\"?", "")
      sub("\"?[[:space:]]*$", "")
      print
      exit
    }
  ' "$1"
}

# _write_kv <file> <var> <value>   ->   set VAR="value" in place (single-quoted to keep spaces)
_write_kv() {
  _val=$3
  # Use a delimiter unlikely to appear; values are keychain service names (safe ASCII).
  _delim=$(printf '\036')
  # If the variable line is missing, append it. Otherwise replace it.
  if grep -q "^$2=" "$1" 2>/dev/null; then
    # shellcheck disable=SC1003
    # Portable in-place edit: GNU sed's `sed -i ''` parsing differs from BSD sed,
    # so write to a temp file and rename instead of relying on `sed -i`.
    sed "s${_delim}^$2=.*${_delim}$2=\"$_val\"${_delim}" "$1" > "$1.tmp" && mv "$1.tmp" "$1"
  else
    printf '\n%s="%s"\n' "$2" "$_val" >> "$1"
  fi
}

# _single_key_service <provider>   ->  the Keychain service name a single-key
# provider should use for `crouter add`, or empty if the mode has no
# user-managed key. Covers keychain / env(fallback) / dual-source(API_KEY_REF).
# keypool, none and static are intentionally NOT served here (pool / proxy).
_single_key_service() {
  if is_dual_source; then
    printf '%s' "${API_KEY_REF:-}"
    return
  fi
  case "${AUTH_MODE:-}" in
    keychain) printf '%s' "${AUTH_REFERENCE:-}" ;;
    env)      printf '%s' "${AUTH_KEYCHAIN_FALLBACK:-${AUTH_REFERENCE:-}}" ;;
    *)        printf '' ;;
  esac
}

# _prompt_secret <prompt>   ->  read a secret from /dev/tty with no echo
_prompt_secret() {
  [ -r /dev/tty ] || die "no TTY available; cannot prompt for secret"
  _old_stty=$(stty -g 2>/dev/null || true)
  trap 'stty "$_old_stty" 2>/dev/null; trap - INT TERM' INT TERM
  printf '%s' "$1" >/dev/tty
  stty -echo 2>/dev/null
  IFS= read -r _secret </dev/tty || _secret=
  stty echo 2>/dev/null
  printf '\n' >/dev/tty
  trap - INT TERM
  [ -n "$_old_stty" ] && stty "$_old_stty" 2>/dev/null
  printf '%s' "$_secret"
  unset _secret
}

# _keychain_put <service> <value>   ->  add or update (-U) a generic password for current $USER
_keychain_put() {
  security add-generic-password -U -a "$USER" -s "$1" -w "$2"
}

# _keychain_delete <service>   ->  delete a generic password if present (no error if missing)
_keychain_delete() {
  security delete-generic-password -a "$USER" -s "$1" >/dev/null 2>&1 || true
}

# _next_key_name <provider> <surface>   ->  suggest "<provider>-2", "<provider>-3", ...
_next_key_name() {
  _base=$1
  _n=2
  while security find-generic-password -a "$USER" -s "${_base}-${_n}" >/dev/null 2>&1; do
    _n=$((_n + 1))
  done
  printf '%s-%d' "$_base" "$_n"
}

cmd_add_key() {
  _p=$1; shift
  load_provider "$_p"

  # Pooled providers: multiple keys per surface, rich --surface/--name flags.
  if [ "${AUTH_MODE:-}" = "keypool" ] || [ "${AUTH_MODE:-}" = surfaces ]; then
    if [ "${AUTH_MODE:-}" = surfaces ]; then
      if [ -n "${PLAN_URL:-}" ]; then _surface=plan; else _surface=api; fi
    else
      _surface=main
    fi
    _name=
    while [ $# -gt 0 ]; do
      case $1 in
        --surface) [ $# -ge 2 ] || die "add: --surface needs an argument (plan|api)"
                   _surface=$2; shift 2 ;;
        --surface=*) _surface=${1#--surface=}; shift ;;
        --name)   [ $# -ge 2 ] || die "add: --name needs an argument (keychain service name)"
                  _name=$2; shift 2 ;;
        --name=*) _name=${1#--name=}; shift ;;
        -h|--help) info "usage: crouter add <provider> [--surface plan|api] [--name <service>]"; return 0 ;;
        *) die "add: unknown argument '$1'" ;;
      esac
    done

    _var=$(_surface_var "$_surface")
    _file=$(provider_file "$_p")

    if [ "${AUTH_MODE:-}" = surfaces ]; then
      case $_var in
        PLAN_KEYS) [ -n "${PLAN_URL:-}" ] || die "provider '$_p' has no Token Plan surface" ;;
        API_KEYS)  [ -n "${API_URL:-}" ] || die "provider '$_p' has no pay-as-you-go API surface" ;;
      esac
    fi

    # Pick the next service name if the user didn't provide one.
    if [ -z "$_name" ]; then
      _name=$(_next_key_name "$_p-$_surface")
    fi
    _validate_service_name "$_name"

    # Reject duplicates that are already listed in this surface.
    _existing=$(_read_kv "$_file" "$_var")
    for _w in $_existing; do
      [ "$_w" = "$_name" ] && die "service '$_name' is already in $_var (remove it first if you want to re-add)"
    done

    # Read the secret from the TTY (no echo). Passphrase will not appear in argv or shell history.
    _secret=$(_prompt_secret "Paste key for $_name: ")
    [ -n "$_secret" ] || die "add: empty key; aborting"

    # Store in Keychain (add or update).
    _keychain_put "$_name" "$_secret"
    unset _secret

    # Append to the selected surface declaration in providers/<provider>.sh.
    if [ -z "$_existing" ]; then
      _new="$_name"
    else
      _new="$_existing $_name"
    fi
    _write_kv "$_file" "$_var" "$_new"

    info "added '$_name' to $_surface surface of provider '$_p'"
    info "  $_var=$_new   (file: $_file)"
    info "verify: crouter list $_p"
    return
  fi

  # Single-key providers (keychain / env / dual-source): one Keychain item.
  _service=$(_single_key_service)
  if [ -z "$_service" ]; then
    case "${AUTH_MODE:-}" in
      none|static)
        die "provider '$_p' uses ${AUTH_MODE} auth — credentials are supplied by the local proxy, so there is no API key to add" ;;
      command)
        die "provider '$_p' uses command-based auth (AUTH_REFERENCE); crouter add can't manage it" ;;
      *)
        die "provider '$_p' has no Keychain target for add (set AUTH_KEYCHAIN_FALLBACK / AUTH_REFERENCE / API_KEY_REF)" ;;
    esac
  fi
  [ $# -eq 0 ] || die "add: '$1' is not valid for a single-key provider (no --surface/--name)"

  _secret=$(_prompt_secret "Paste key for $_service ($_p): ")
  [ -n "$_secret" ] || die "add: empty key; aborting"
  _keychain_put "$_service" "$_secret"
  unset _secret

  info "stored key for '$_p' in Keychain service '$_service'"
  info "verify: crouter list $_p"
}

cmd_remove_key() {
  _p=$1; shift
  load_provider "$_p"

  if [ "${AUTH_MODE:-}" = "keypool" ] || [ "${AUTH_MODE:-}" = surfaces ]; then
    if [ "${AUTH_MODE:-}" = surfaces ]; then
      if [ -n "${PLAN_URL:-}" ]; then _surface=plan; else _surface=api; fi
    else
      _surface=main
    fi
    _name=
    _yes=0
    while [ $# -gt 0 ]; do
      case $1 in
        --surface) [ $# -ge 2 ] || die "remove: --surface needs an argument (plan|api)"
                   _surface=$2; shift 2 ;;
        --surface=*) _surface=${1#--surface=}; shift ;;
        --name)   [ $# -ge 2 ] || die "remove: --name needs an argument"
                  _name=$2; shift 2 ;;
        --name=*) _name=${1#--name=}; shift ;;
        -y|--yes) _yes=1; shift ;;
        -h|--help) info "usage: crouter remove <provider> --name <service> [--surface plan|api] [-y]"; return 0 ;;
        *) die "remove: unknown argument '$1'" ;;
      esac
    done
    [ -n "$_name" ] || die "remove: --name is required (the keychain service name to remove)"
    _validate_service_name "$_name"

    _var=$(_surface_var "$_surface")
    _file=$(provider_file "$_p")

    _existing=$(_read_kv "$_file" "$_var")
    _found=0
    _new=
    for _w in $_existing; do
      if [ "$_w" = "$_name" ]; then
        _found=1
      else
        _new="$_new $_w"
      fi
    done
    _new=$(echo "$_new" | sed 's/^ *//; s/ *$//')
    [ "$_found" -eq 1 ] || die "remove: service '$_name' is not in $_var"

    if [ "$_yes" -eq 0 ]; then
      printf 'remove %s from %s surface of %s and delete the Keychain item? [y/N] ' \
        "$_name" "$_surface" "$_p" >/dev/tty
      _ans=
      IFS= read -r _ans </dev/tty || _ans=
      case "$_ans" in y|Y|yes|YES) ;; *) info "aborted"; return 0 ;; esac
    fi

    _write_kv "$_file" "$_var" "$_new"
    _keychain_delete "$_name"

    info "removed '$_name' from $_surface surface of provider '$_p'"
    return
  fi

  # Single-key provider: delete the one Keychain item.
  _service=$(_single_key_service)
  [ -n "$_service" ] || die "provider '$_p' has no single-key to remove (mode=${AUTH_MODE:-})"

  _yes=0
  while [ $# -gt 0 ]; do
    case $1 in
      -y|--yes) _yes=1; shift ;;
      -h|--help) info "usage: crouter remove <provider> [-y]"; return 0 ;;
      *) die "remove: unknown argument '$1'" ;;
    esac
  done

  if [ "$_yes" -eq 0 ]; then
    printf 'delete Keychain item %s for provider %s? [y/N] ' "$_service" "$_p" >/dev/tty
    _ans=
    IFS= read -r _ans </dev/tty || _ans=
    case "$_ans" in y|Y|yes|YES) ;; *) info "aborted"; return 0 ;; esac
  fi

  _keychain_delete "$_service"
  info "removed Keychain item '$_service' for provider '$_p'"
}

# cmd_list_keys [provider]   ->  list registered keys. No provider = all.
cmd_list_keys() {
  if [ -z "${1:-}" ]; then
    for _n in $(provider_names); do
      cmd_list_keys_one "$_n"
      echo
    done
    return
  fi
  cmd_list_keys_one "$1"
}

cmd_list_keys_one() {
  _p=$1
  load_provider "$_p"
  _file=$(provider_file "$_p")

  _ds=''; is_dual_source && _ds=' (dual-source)'
  printf 'provider: %s   auth_mode: %s%s\n' "$_p" "${AUTH_MODE:-}" "$_ds"

  # Dual-source: preferred "default account" (env) + fallback API key (env/keychain).
  if is_dual_source; then
    if [ -n "${DEFAULT_TOKEN_ENV:-}" ]; then
      _dt=$(printenv "$DEFAULT_TOKEN_ENV" 2>/dev/null || true)
      [ -z "$_dt" ] && [ -n "${DEFAULT_TOKEN_ENV_FALLBACK:-}" ] && \
        _dt=$(printenv "$DEFAULT_TOKEN_ENV_FALLBACK" 2>/dev/null || true)
      if [ -n "$_dt" ]; then printf '  - default account: env:%s set\n' "$DEFAULT_TOKEN_ENV"
      else printf '  - default account: env:%s unset\n' "$DEFAULT_TOKEN_ENV"; fi
    fi
    if [ -n "${API_KEY_ENV:-}" ]; then
      _ak=$(printenv "$API_KEY_ENV" 2>/dev/null || true)
      if [ -n "$_ak" ]; then printf '  - api key: env:%s set\n' "$API_KEY_ENV"
      else printf '  - api key: env:%s unset\n' "$API_KEY_ENV"; fi
    fi
    if [ -n "${API_KEY_REF:-}" ]; then
      if security find-generic-password -a "$USER" -s "$API_KEY_REF" >/dev/null 2>&1; then
        printf '  - api key: keychain:%s in Keychain\n' "$API_KEY_REF"
      else
        printf '  - api key: keychain:%s MISSING\n' "$API_KEY_REF"
      fi
    fi
    return
  fi

  case "${AUTH_MODE:-}" in
    keypool|surfaces)
      if [ "${AUTH_MODE:-}" = surfaces ]; then _surfaces="plan api"; else _surfaces="main plus"; fi
      for _surface in $_surfaces; do
        _var=$(_surface_var "$_surface")
        _existing=$(_read_kv "$_file" "$_var")
        [ -z "$_existing" ] && continue
        printf '%-8s surface (%s):\n' "$_surface" "$_var"
        for _w in $_existing; do
          if security find-generic-password -a "$USER" -s "$_w" >/dev/null 2>&1; then
            _st='in Keychain'
          else
            _st='MISSING from Keychain'
          fi
          printf '  - %-40s %s\n' "$_w" "$_st"
        done
      done
      if [ "${AUTH_MODE:-}" = surfaces ]; then
        [ -n "${PLAN_KEY_ENV:-}" ] && printf '  - plan env:%s %s\n' "$PLAN_KEY_ENV" \
          "$([ -n "$(printenv "$PLAN_KEY_ENV" 2>/dev/null)" ] && printf set || printf unset)"
        [ -n "${API_KEY_ENV:-}" ] && printf '  - api env:%s %s\n' "$API_KEY_ENV" \
          "$([ -n "$(printenv "$API_KEY_ENV" 2>/dev/null)" ] && printf set || printf unset)"
      fi
      ;;
    keychain)
      _ref=${AUTH_REFERENCE:-}
      if [ -n "$_ref" ] && security find-generic-password -a "$USER" -s "$_ref" >/dev/null 2>&1; then
        printf '  - %-40s in Keychain\n' "$_ref"
      else
        printf '  - %-40s MISSING\n' "${_ref:-<AUTH_REFERENCE unset>}"
      fi
      ;;
    env)
      _v=$(printenv "${AUTH_REFERENCE:-}" 2>/dev/null || true)
      if [ -n "$_v" ]; then
        printf '  - env:%s set\n' "${AUTH_REFERENCE:-}"
      else
        printf '  - env:%s unset\n' "${AUTH_REFERENCE:-}"
      fi
      _svc=${AUTH_KEYCHAIN_FALLBACK:-}
      if [ -n "$_svc" ]; then
        if security find-generic-password -a "$USER" -s "$_svc" >/dev/null 2>&1; then
          printf '  - keychain:%s in Keychain\n' "$_svc"
        else
          printf '  - keychain:%s MISSING\n' "$_svc"
        fi
      fi
      ;;
    static)
      printf '  - static placeholder: %s\n' "${AUTH_REFERENCE:-<none>}"
      ;;
    none)
      printf '  - (no key — local proxy supplies auth)\n'
      ;;
    native)
      printf '  - (native cloud credential chain; no crouter key)\n'
      ;;
    *)
      printf '  - (unsupported AUTH_MODE: %s)\n' "${AUTH_MODE:-}"
      ;;
  esac
}
