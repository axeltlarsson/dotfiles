# shellcheck shell=bash
# bash completion for theme — grammar read from the dispatcher in config/scripts/theme.sh
# @ blob 9d71223; verified by theme.cases.tsv. config/theme.nix fails the build when the
# command list drifts from the script's case arms.
# Must stay sourceable by macOS /bin/bash 3.2: no compopt, mapfile or declare -A.

# The shell's words up to the cursor, in words[]/cword. bash 4+ splits COMP_WORDS at '=',
# ':' and '@'; 3.2 does not. Glue the pieces back unless whitespace separates them.
_theme__split() {
  local line=${COMP_LINE:0:COMP_POINT} i w
  line=${line#*"${COMP_WORDS[0]}"}
  words=("${COMP_WORDS[0]}")
  cword=0
  for ((i = 1; i <= COMP_CWORD; i++)); do
    w=${COMP_WORDS[i]-}
    if [[ $line == [[:space:]]* ]]; then
      cword=$((cword + 1))
      words[cword]=
      line=${line#"${line%%[![:space:]]*}"}
    fi
    if ((i == COMP_CWORD)); then w=$line; fi
    words[cword]=${words[cword]}$w
    line=${line#"$w"}
  done
}

# readline replaces only $cur: match the whole word, then strip the part before $cur
_theme__words() {
  local w
  for w in "$@"; do
    [[ $w == "$pre$cur"* ]] || continue
    COMPREPLY+=("${w#"$pre"}")
  done
}

_theme() {
  # $2, not ${COMP_WORDS[COMP_CWORD]}: that is a lone ':' after "x:" on bash 4+
  local cur=${2-} cword pre
  local -a words
  COMPREPLY=()
  _theme__split
  pre=${words[cword]%"$cur"}
  if [[ $pre == [\"\']* ]]; then pre=; fi

  case $cword in
    1) _theme__words light dark toggle auto sync ;; # theme.sh:145-171
    2) if [[ ${words[1]} == sync ]]; then _theme__words --force; fi ;; # theme.sh:167 reads only $2
  esac
  return 0
}

# No -o options: candidates are plain words, and nothing falls back to files past the last argument
complete -F _theme theme
