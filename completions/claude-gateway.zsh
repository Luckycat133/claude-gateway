# Zsh completion for claude-gateway.
# Source it from your .zshrc, or drop it into a directory on your $fpath
# (named `_claude-gateway` there).

_claude_gateway_providers() {
  local dir="${CLAUDE_GATEWAY_PROVIDERS_DIR:-$(cd "$(dirname "${(%):-%x}")/../providers" && pwd)}"
  [[ -d "$dir" ]] || return
  local f
  for f in "$dir"/*.sh; do
    [[ -f "$f" ]] || continue
    case "$(basename "$f")" in
      lib*) continue ;;
    esac
    basename "$f" .sh
  done
}

_claude_gateway_complete() {
  local -a cmds providers
  cmds=(list status doctor start stop run help --version)
  providers=(${(f)"$(_claude_gateway_providers)"})
  if (( CURRENT == 2 )); then
    compadd -- $cmds
  elif (( CURRENT == 3 )); then
    case "$words[2]" in
      status|doctor|start|stop|run) compadd -- $providers ;;
    esac
  fi
}
compdef _claude_gateway_complete claude-gateway
