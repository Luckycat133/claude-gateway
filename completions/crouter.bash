#!/bin/bash
# Bash completion for crouter.
# Source it from your shell rc, e.g.:
#   source /path/to/crouters/completions/crouter.bash
# or symlink it into your bash-completion directory.

_crouter_providers() {
  # List provider names from the providers/ dir (exclude lib/).
  local dir="${CROUTER_PROVIDERS_DIR:-}"
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

_crouter_complete() {
  local cur prev cmds providers
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  cmds="claude all list doctor add remove provider config logs uninstall help --version"
  providers="$(_crouter_providers)"

  if [ "$COMP_CWORD" -eq 1 ]; then
    # Position 1 is either a subcommand or a provider name (`crouter deepseek`).
    # shellcheck disable=SC2207
    COMPREPLY=( $(compgen -W "$cmds $providers" -- "$cur") )
  else
    case "$prev" in
      doctor|add|remove|provider|config|logs)
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "$providers" -- "$cur") ) ;;
    esac
    if [ "${COMP_WORDS[1]}" = all ]; then
      COMPREPLY=( $(compgen -W "--check" -- "$cur") )
    elif [ "${COMP_WORDS[1]}" = add ]; then
      COMPREPLY+=( $(compgen -W "--surface plan api --name --stdin" -- "$cur") )
    fi
  fi
}
complete -F _crouter_complete crouter
