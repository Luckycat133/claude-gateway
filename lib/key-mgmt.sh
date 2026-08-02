#!/bin/sh
# Key management for keypool providers. Edits a provider's AUTH_KEYS / PLUS_KEYS
# lines in providers/<name>.sh and stores/updates the secret in macOS Keychain.
# Never prints the secret value.
# Depends on: provider.sh (provider_file, load_provider).

# _surface_var <name>   ->  variable name holding the keys for that surface.
# Supported: "main" -> AUTH_KEYS, "plus" -> PLUS_KEYS.
_surface_var() {
  case $1 in
    main)    printf 'AUTH_KEYS' ;;
    plus)  printf 'PLUS_KEYS' ;;
    *) die "unknown surface '$1' (expected: main or plus)" ;;
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
    sed -i '' "s${_delim}^$2=.*${_delim}$2=\"$_val\"${_delim}" "$1"
  else
    printf '\n%s="%s"\n' "$2" "$_val" >> "$1"
  fi
}

# _require_keypool <provider>   ->  die if provider isn't in keypool mode
_require_keypool() {
  [ "${AUTH_MODE:-}" = keypool ] || die "provider '$1' is not in keypool mode (AUTH_MODE='${AUTH_MODE:-}'); key management is for keypool only"
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
  _require_keypool "$_p"

  _surface=main
  _name=
  while [ $# -gt 0 ]; do
    case $1 in
      --surface) [ $# -ge 2 ] || die "add: --surface needs an argument (main|plus)"
                 _surface=$2; shift 2 ;;
      --surface=*) _surface=${1#--surface=}; shift ;;
      --name)   [ $# -ge 2 ] || die "add: --name needs an argument (keychain service name)"
                _name=$2; shift 2 ;;
      --name=*) _name=${1#--name=}; shift ;;
      -h|--help) info "usage: crouter add <provider> [--surface main|plus] [--name <service>]"; return 0 ;;
      *) die "add: unknown argument '$1'" ;;
    esac
  done

  _var=$(_surface_var "$_surface")
  _file=$(provider_file "$_p")

  # Pick the next service name if the user didn't provide one.
  if [ -z "$_name" ]; then
    _name=$(_next_key_name "$_p" "$_surface")
  fi

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

  # Append to AUTH_KEYS / PLUS_KEYS in providers/<provider>.sh.
  if [ -z "$_existing" ]; then
    _new="$_name"
  else
    _new="$_existing $_name"
  fi
  _write_kv "$_file" "$_var" "$_new"

  info "added '$_name' to $_surface surface of provider '$_p'"
  info "  $_var=$_new   (file: $_file)"
  info "verify: crouter doctor $_p"
}

cmd_remove_key() {
  _p=$1; shift
  load_provider "$_p"
  _require_keypool "$_p"

  _surface=main
  _name=
  _yes=0
  while [ $# -gt 0 ]; do
    case $1 in
      --surface) [ $# -ge 2 ] || die "remove: --surface needs an argument (main|plus)"
                 _surface=$2; shift 2 ;;
      --surface=*) _surface=${1#--surface=}; shift ;;
      --name)   [ $# -ge 2 ] || die "remove: --name needs an argument"
                _name=$2; shift 2 ;;
      --name=*) _name=${1#--name=}; shift ;;
      -y|--yes) _yes=1; shift ;;
      -h|--help) info "usage: crouter remove <provider> --name <service> [--surface main|plus] [-y]"; return 0 ;;
      *) die "remove: unknown argument '$1'" ;;
    esac
  done
  [ -n "$_name" ] || die "remove: --name is required (the keychain service name to remove)"

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
}

cmd_list_keys() {
  _p=$1
  load_provider "$_p"

  _file=$(provider_file "$_p")
  printf 'provider: %s   auth_mode: %s\n' "$_p" "${AUTH_MODE:-}"

  case "${AUTH_MODE:-}" in
    keypool)
      for _surface in main plus; do
        _var=$(_surface_var "$_surface")
        _existing=$(_read_kv "$_file" "$_var")
        if [ -z "$_existing" ]; then continue; fi
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
      ;;
    keychain)
      _ref=${AUTH_REFERENCE:-}
      if [ -n "$_ref" ] && security find-generic-password -a "$USER" -s "$_ref" >/dev/null 2>&1; then
        printf '  - %-40s in Keychain   (single-key AUTH_MODE=keychain)\n' "$_ref"
      else
        printf '  - %-40s MISSING\n' "${_ref:-<AUTH_REFERENCE unset>}"
      fi
      ;;
    env)
      _v=$(printenv "${AUTH_REFERENCE:-}" 2>/dev/null || true)
      if [ -n "$_v" ]; then
        printf '  - env:%s                                set\n' "${AUTH_REFERENCE:-}"
      else
        printf '  - env:%s                                unset\n' "${AUTH_REFERENCE:-}"
      fi
      ;;
    static)
      printf '  - static placeholder: %s\n' "${AUTH_REFERENCE:-<none>}"
      ;;
    none)
      printf '  (no credential required)\n'
      ;;
    *)
      printf '  (unsupported AUTH_MODE: %s)\n' "${AUTH_MODE:-}"
      ;;
  esac
}
