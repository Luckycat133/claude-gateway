#!/bin/bash
# Bash completion for claude-gateway.
# Source it from your shell rc, e.g.:
#   source /path/to/claude-gateways/completions/claude-gateway.bash
# or symlink it into your bash-completion directory.

_claude_gateway_providers() {
  # List provider names from the providers/ dir (exclude lib/).
  local dir="${CLAUDE_GATEWAY_PROVIDERS_DIR:-}"
  if [ -z "$dir" ] && [ -n "${BASH_SOURCE:-}" ]; then
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../providers" && pwd)
  fi
  [ -d "$dir" ] || return 0
  local f
  for f in "$dir"/*.sh; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      lib*) continue ;;
    esac
    basename "$f" .sh
  done
}

_claude_gateway_complete() {
  local cur prev cmds providers
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  cmds="list status doctor start stop run help --version"
  providers="$(_claude_gateway_providers)"

  if [ "$COMP_CWORD" -eq 1 ]; then
    # shellcheck disable=SC2207
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
  else
    case "$prev" in
      status|doctor|start|stop|run)
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "$providers" -- "$cur") ) ;;
    esac
  fi
}
complete -F _claude_gateway_complete claude-gateway
