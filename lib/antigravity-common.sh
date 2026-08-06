#!/bin/sh
# Shared helpers for Antigravity-based providers.
# Sourced by providers/antigravity-*.sh; not a provider itself.

antigravity_port() { printf '%s' "${ANTIGRAVITY_PORT:-18080}"; }
antigravity_base_url() { printf 'http://127.0.0.1:%s' "$(antigravity_port)"; }

antigravity_gateway_running() {
  curl -fsS --max-time 2 "$(antigravity_base_url)/health" >/dev/null 2>&1
}

# PRE_START hook: start the local gateway if it is not already healthy.
antigravity_ensure_gateway() {
  if antigravity_gateway_running; then
    return 0
  fi

  _proxy_dir=${ANTIGRAVITY_PROXY_DIR:-$ROOT_DIR/antigravity-claude-proxy}
  [ -d "$_proxy_dir" ] || {
    echo "Antigravity proxy directory not found: $_proxy_dir (set ANTIGRAVITY_PROXY_DIR in config.sh)" >&2
    return 1
  }
  command -v npm >/dev/null 2>&1 || { echo "npm not found; cannot start Antigravity gateway." >&2; return 1; }

  _log_dir=${LOG_DIR:-$ROOT_DIR/logs}
  mkdir -p "$_log_dir"
  echo "Starting Antigravity gateway on 127.0.0.1:$(antigravity_port) ..."
  (
    cd "$_proxy_dir" || exit 1
    nohup env HOST=127.0.0.1 PORT="$(antigravity_port)" npm start \
      > "$_log_dir/antigravity-proxy.log" 2>&1 &
  )

  _i=0
  while [ "$_i" -lt 30 ]; do
    if antigravity_gateway_running; then
      echo "Antigravity gateway is up."
      return 0
    fi
    sleep 0.5
    _i=$((_i + 1))
  done
  echo "Antigravity gateway did not become healthy; see $_log_dir/antigravity-proxy.log" >&2
  return 1
}

# POST_STOP hook: stop the node process listening on the gateway port.
antigravity_stop_gateway() {
  command -v lsof >/dev/null 2>&1 || { echo "lsof not found; cannot determine gateway PID." >&2; return 1; }
  _pid=$(lsof -t -a -iTCP:"$(antigravity_port)" -sTCP:LISTEN -c node 2>/dev/null | head -n 1)
  if [ -z "$_pid" ]; then
    echo "Antigravity gateway is not running."
    return 0
  fi
  kill -TERM "$_pid" 2>/dev/null
  _i=0
  while [ "$_i" -lt 20 ]; do
    kill -0 "$_pid" 2>/dev/null || break
    sleep 0.5
    _i=$((_i + 1))
  done
  if kill -0 "$_pid" 2>/dev/null; then
    kill -KILL "$_pid" 2>/dev/null && echo "Force-killed Antigravity gateway (PID $_pid)."
  else
    echo "Stopped Antigravity gateway (PID $_pid)."
  fi
}
