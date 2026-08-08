#!/bin/sh
# Public key-management vocabulary distinguishes Token Plan from API keys while
# retaining main/plus aliases for existing scripts.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
AUTH_MODE=surfaces
die() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }
info() { :; }
. "$ROOT_DIR/lib/key-mgmt.sh"

[ "$(_surface_var plan)" = PLAN_KEYS ]
[ "$(_surface_var token-plan)" = PLAN_KEYS ]
[ "$(_surface_var api)" = API_KEYS ]
[ "$(_surface_var main)" = API_KEYS ]
[ "$(_surface_var plus)" = PLAN_KEYS ]

AUTH_MODE=keypool
[ "$(_surface_var main)" = AUTH_KEYS ]
[ "$(_surface_var plus)" = PLUS_KEYS ]

_validate_service_name 'demo-plan-2'
if (_validate_service_name '../provider.sh') >/dev/null 2>&1; then
  printf 'FAIL  key management accepted a path-like service name\n' >&2
  exit 1
fi
if (_validate_service_name 'broken" name') >/dev/null 2>&1; then
  printf 'FAIL  key management accepted shell syntax in a service name\n' >&2
  exit 1
fi

printf 'ok    key management exposes plan/api surfaces with legacy aliases\n'
