# shellcheck shell=bash
# bash completion for ferry — grammar read from the dispatcher in ./ferry (see the
# grammar table in PR.md); verified by ferry.cases.tsv. Literal lists mirror the script.
# Runs on macOS /bin/bash 3.2 (no mapfile, no compopt): the 3.2 branch adds the trailing
# space / directory slash itself; only quoting of special characters in file names is lost.

# bash 3.2 has no compopt
_ferry__have_compopt() { type compopt >/dev/null 2>&1; }

# The shell's words up to the cursor, in words[]/cword. bash 4+ splits COMP_WORDS at '=', ':' and
# '@' (--tag=x, a file name a:b); 3.2 does not. Glue the pieces back unless whitespace separates them.
_ferry__split() {
  local line=${COMP_LINE:0:COMP_POINT} i w
  line=${line#*"${COMP_WORDS[0]}"}
  words=("${COMP_WORDS[0]}")
  cword=0
  for ((i = 1; i <= COMP_CWORD; i++)); do
    w=${COMP_WORDS[i]-}
    if [[ $line == [[:space:]]* ]]; then # whitespace starts a word; otherwise w is glued on
      cword=$((cword + 1))
      words[cword]=
      line=${line#"${line%%[![:space:]]*}"}
    fi
    if ((i == COMP_CWORD)); then w=$line; fi # the cursor's word only up to the cursor
    words[cword]=${words[cword]}$w
    line=${line#"$w"}
  done
}

# offer every word matching the whole current word; readline replaces only $cur, so strip $pre
_ferry__words() {
  local w
  for w in "$@"; do
    [[ $w == "$pre$cur"* ]] || continue
    w=${w#"$pre"}
    if _ferry__have_compopt || [[ $w == *= ]]; then
      COMPREPLY+=("$w")
    else
      COMPREPLY+=("$w ") # bash 3.2: registered with -o nospace, so add the space here
    fi
  done
}

# parse_opts "${@:4}": flags only from word 4 on; skip those already given
_ferry__flags() {
  local w p
  [[ $pre$cur == --*=* ]] && return 0 # the value of --tag=: free text
  for w in "$@"; do
    for p in "${words[@]:4:cword-4}"; do
      [[ ${p%%=*} == "${w%%=*}" ]] && continue 2
    done
    _ferry__words "$w"
  done
}

_ferry__files() {
  local f
  if _ferry__have_compopt; then
    compopt -o filenames # readline adds / to directories and quotes special characters
    while IFS= read -r f; do COMPREPLY+=("${f#"$pre"}"); done < <(compgen -f -- "$pre$cur")
  else
    while IFS= read -r f; do
      if [[ -d $f ]]; then COMPREPLY+=("${f#"$pre"}/"); else COMPREPLY+=("${f#"$pre"} "); fi
    done < <(compgen -f -- "$pre$cur")
  fi
}

_ferry() {
  # $2 is the text readline will replace; never ${COMP_WORDS[COMP_CWORD]}
  local cur=${2-} cword pre
  local -a words
  COMPREPLY=()
  _ferry__split
  pre=${words[cword]%"$cur"}
  if [[ $pre == [\"\']* ]]; then pre=; fi

  case $cword in
    1) _ferry__words ship fetch dock status help ;;
    *)
      case ${words[1]} in
        ship)
          case $cword in
            2) _ferry__words eu us ;;
            3) _ferry__files ;;                   # ship checks [ -f "$3" ]
            *) _ferry__flags --force --tag= ;;
          esac
          ;;
        fetch)
          case $cword in
            2) _ferry__words eu us ;;
            3) ;;                                 # a name in the bucket, not a local path
            *) _ferry__flags --force ;;           # fetch parses --tag but never uses it
          esac
          ;;
        dock)
          case $cword in
            2) _ferry__words north south east ;;
            3) _ferry__words ro rw ;;             # required: the script checks $# -eq 3
          esac
          ;;
        status)
          if ((cword == 2)); then _ferry__words --json; fi # only the literal --json, only as $2
          ;;
      esac
      ;;
  esac

  # --tag= takes its value in the same word: no space after the '='
  if [[ ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == *= ]] && _ferry__have_compopt; then
    compopt -o nospace
  fi
  return 0
}

if _ferry__have_compopt; then
  complete -F _ferry ferry
else
  complete -o nospace -F _ferry ferry # bash 3.2: spaces are appended by _ferry__words
fi
