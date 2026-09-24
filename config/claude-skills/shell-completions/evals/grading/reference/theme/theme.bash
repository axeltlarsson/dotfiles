# shellcheck shell=bash
# bash completion for theme — grammar read from the dispatcher in config/scripts/theme.sh;
# verified by theme.cases.tsv. Runs on macOS /bin/bash 3.2 (no compopt: spaces added here).

_theme__words() {
  local w
  for w in "$@"; do
    [[ $w == "$cur"* ]] || continue
    if type compopt >/dev/null 2>&1; then
      COMPREPLY+=("$w")
    else
      COMPREPLY+=("$w ") # bash 3.2: registered with -o nospace
    fi
  done
}

_theme() {
  local cur=${2-}
  COMPREPLY=()
  case $COMP_CWORD in
    1) _theme__words light dark toggle auto sync ;; # bare `theme` prints; `theme help` is a usage error
    2) if [[ ${COMP_WORDS[1]} == sync ]]; then _theme__words --force; fi ;; # theme.sh: apply "${2:-}" — only the literal --force acts
  esac
  return 0
}

if type compopt >/dev/null 2>&1; then
  complete -F _theme theme
else
  complete -o nospace -F _theme theme
fi
