# Zsh completion for crouter.
# Source it from your .zshrc, or drop it into a directory on your $fpath
# (named `_crouter` there).

_crouter_providers() {
  local dir="${CROUTER_PROVIDERS_DIR:-$(cd "$(dirname "${(%):-%x}")/../providers" && pwd)}"
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

_crouter_complete() {
  local -a cmds providers
  cmds=(list doctor add remove provider config logs uninstall help --version)
  providers=(${(f)"$(_crouter_providers)"})
  if (( CURRENT == 2 )); then
    compadd -- $cmds
  elif (( CURRENT == 3 )); then
    case "$words[2]" in
      doctor|add|remove|provider|config|logs) compadd -- $providers ;;
    esac
  fi
}
compdef _crouter_complete crouter
