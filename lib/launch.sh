#!/bin/sh
# Claude Code launch with isolated env. Sourced by bin/crouter.
# launch_claude <main_model> <bypass_auth> [claude args...]
#   Builds a minimal, terminal-safe "env -i" environment and launches Claude Code
#   as a child process (so POST_STOP / any local proxy is reaped on exit).
# Reads these globals at call time: CLAUDE_BIN, EFFORT, EXTRA_ENV, MODEL_*,
# CONTEXT_TOKENS, AUTH_MODE, AUTH_TOKEN, KEYPOOL_URL, BASE_URL, POST_STOP,
# and the standard shell vars (LANG, TERM, SHELL, PATH, USER, HOME, COLORTERM).

launch_claude() {
  _main_model=$1; _bypass=$2; shift 2

  [ -n "$CLAUDE_BIN" ] || die "claude binary not found; set CLAUDE_BIN in config.sh"
  [ -x "$CLAUDE_BIN" ] || die "claude binary is not executable: $CLAUDE_BIN"

  # Build "env -i KEY=VAL ... claude args..." via positional parameters so
  # values with spaces survive. Everything is prepended in front of "$@".
  set -- "$CLAUDE_BIN" "$@"

  # Reasoning effort (Claude Code --effort). Inject the provider default unless
  # the user already passed --effort. Valid levels: low|medium|high|xhigh|max.
  case "${EFFORT:-}" in
    ""|low|medium|high|xhigh|max) ;;
    *) info "warn: EFFORT='$EFFORT' is not a valid Claude Code effort level (low|medium|high|xhigh|max); ignoring"; EFFORT="" ;;
  esac
  if [ -n "${EFFORT:-}" ]; then
    _has_effort=0
    for _arg in "$@"; do
      case "$_arg" in --effort) _has_effort=1; break ;; esac
    done
    if [ "$_has_effort" -eq 0 ]; then
      _claude_bin="$1"; shift
      set -- "$_claude_bin" "--effort" "$EFFORT" "$@"
    fi
  fi

  if [ -n "$EXTRA_ENV" ]; then
    _old_ifs=$IFS
    IFS='
'
    for _pair in $EXTRA_ENV; do
      [ -n "$_pair" ] && set -- "$_pair" "$@"
    done
    IFS=$_old_ifs
  fi

  # Model aliases; caller may override any of them per session.
  set -- "CLAUDE_CODE_SUBAGENT_MODEL=$MODEL_SUBAGENT" "$@"
  set -- "ANTHROPIC_DEFAULT_HAIKU_MODEL=$MODEL_HAIKU" "$@"
  set -- "ANTHROPIC_DEFAULT_SONNET_MODEL=$MODEL_SONNET" "$@"
  set -- "ANTHROPIC_DEFAULT_OPUS_MODEL=$MODEL_OPUS" "$@"
  set -- "ANTHROPIC_MODEL=$_main_model" "$@"
  [ -n "$CONTEXT_TOKENS" ] && set -- "CLAUDE_CODE_MAX_CONTEXT_TOKENS=$CONTEXT_TOKENS" "$@"

  # A local proxy (keypool rotation or dual-source failover) owns auth: Claude
  # Code just talks to it with a placeholder credential.
  if [ -n "${KEYPOOL_URL:-}" ] && [ "$_bypass" -eq 0 ]; then
    set -- "ANTHROPIC_BASE_URL=$KEYPOOL_URL" "$@"
    set -- "ANTHROPIC_API_KEY=keypool-local" "$@"
    set -- "ANTHROPIC_AUTH_TOKEN=keypool-local" "$@"
  elif [ "${AUTH_MODE:-}" = "keypool" ] && [ "$_bypass" -eq 0 ]; then
    die "keypool proxy not started"
  elif [ -n "$AUTH_TOKEN" ]; then
    # Header shape matters. `_AUTH_SCHEME` is set by resolve_dual_source():
    #   bearer     -> Authorization: Bearer  (Anthropic subscription OAuth,
    #                 OpenRouter, OpenAI-compatible gateways). Sending such a
    #                 token as x-api-key gets it rejected upstream.
    #   x-api-key  -> x-api-key              (Anthropic Console API key)
    # Legacy providers leave it unset: keep the historical both-headers behavior.
    case "${_AUTH_SCHEME:-both}" in
      bearer)
        set -- "ANTHROPIC_AUTH_TOKEN=$AUTH_TOKEN" "$@" ;;
      x-api-key)
        set -- "ANTHROPIC_API_KEY=$AUTH_TOKEN" "$@" ;;
      *)
        set -- "ANTHROPIC_API_KEY=$AUTH_TOKEN" "$@"
        set -- "ANTHROPIC_AUTH_TOKEN=$AUTH_TOKEN" "$@" ;;
    esac
  fi
  set -- "ANTHROPIC_BASE_URL=${KEYPOOL_URL:-$BASE_URL}" "$@"

  # Minimal, terminal-safe environment. No shell leftovers (NO_COLOR etc.).
  set -- "LANG=${LANG:-en_US.UTF-8}" "$@"
  set -- "COLORTERM=${COLORTERM:-truecolor}" "$@"
  set -- "TERM=${TERM:-xterm-256color}" "$@"
  set -- "SHELL=${SHELL:-/bin/zsh}" "$@"
  set -- "PATH=$PATH" "$@"
  set -- "USER=$USER" "$@"
  set -- "HOME=$HOME" "$@"

  if [ -n "${KEYPOOL_PID:-}" ] && [ "$_bypass" -eq 0 ]; then
    # Run as a child (not exec) so we can reap the proxy on exit.
    env -i "$@" &
    _cg_pid=$!
    trap '[ -n "${POST_STOP:-}" ] && eval "$POST_STOP"; kill "$KEYPOOL_PID" 2>/dev/null; kill "$_cg_pid" 2>/dev/null' EXIT INT TERM
    wait "$_cg_pid"
    _rc=$?
    kill "$KEYPOOL_PID" 2>/dev/null
    exit "${_rc:-0}"
  fi

  # Run as a child (not exec) so POST_STOP runs on exit and any local proxy
  # (e.g. Antigravity on 127.0.0.1:18080) is cleaned up instead of leaking.
  env -i "$@" &
  _cg_pid=$!
  trap '[ -n "${POST_STOP:-}" ] && eval "$POST_STOP"; kill "$_cg_pid" 2>/dev/null' EXIT INT TERM
  wait "$_cg_pid"
  _rc=$?
  [ -n "${POST_STOP:-}" ] && eval "$POST_STOP"
  exit "${_rc:-0}"
}
