#!/bin/sh
# A healthy Antigravity proxy that predates crouter belongs to the user and
# must never be killed by the session's POST_STOP hook.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t crouter-antigravity-owner)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

. "$ROOT_DIR/lib/antigravity-common.sh"
antigravity_gateway_running() { return 0; }
lsof() { : > "$TMP_DIR/lsof-called"; return 0; }

antigravity_ensure_gateway
antigravity_stop_gateway

[ ! -e "$TMP_DIR/lsof-called" ] || {
  printf 'FAIL  POST_STOP inspected/killed a pre-existing Antigravity gateway\n' >&2
  exit 1
}

printf 'ok    Antigravity leaves pre-existing gateways owned by the user\n'
