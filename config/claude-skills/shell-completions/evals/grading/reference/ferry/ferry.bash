# shellcheck shell=bash
# bash completion for ferry — grammar read from the dispatcher in ./ferry (see the
# grammar table in PR.md); verified by ferry.cases.tsv. Literal lists mirror the script.
# Runs on macOS /bin/bash 3.2 (no mapfile, no compopt): the 3.2 branch adds the trailing
# space / directory slash itself; only quoting of special characters in file names is lost.

_ferry__have_compopt() { type compopt >/dev/null 2>&1; }

# offer every word matching $cur; skip options already on the line
_ferry__words() {
  local w p
  for w in "$@"; do
    [[ $w == "$cur"* ]] || continue
    if [[ $w == -* ]]; then
      for p in "${COMP_WORDS[@]:4:COMP_CWORD-4}"; do
        [[ ${p%%=*} == "${w%%=*}" ]] && continue 2
      done
    fi
    if _ferry__have_compopt || [[ $w == *= ]]; then
      COMPREPLY+=("$w")
    else
      COMPREPLY+=("$w ") # bash 3.2: registered with -o nospace, so add the space here
    fi
  done
}

_ferry__files() {
  local f
  if _ferry__have_compopt; then
    compopt -o filenames # readline adds / to directories and quotes special characters
    while IFS= read -r f; do COMPREPLY+=("$f"); done < <(compgen -f -- "$cur")
  else
    while IFS= read -r f; do
      if [[ -d $f ]]; then COMPREPLY+=("$f/"); else COMPREPLY+=("$f "); fi
    done < <(compgen -f -- "$cur")
  fi
}

_ferry() {
  local cur=${2-} cmd=${COMP_WORDS[1]-} lw
  COMPREPLY=()
  # the current word as typed: readline splits COMP_WORDS at '=' on bash 4+ but not on 3.2,
  # so look at the line instead of COMP_WORDS to see a --opt=value word
  lw=${COMP_LINE:0:COMP_POINT}
  lw=${lw##*[[:space:]]}
  if [[ $lw == --*=* ]]; then return 0; fi # value of --tag=: free text

  case $COMP_CWORD in
    1) _ferry__words ship fetch dock status help ;;
    *)
      case $cmd in
        ship | fetch)
          case $COMP_CWORD in
            2) _ferry__words eu us ;;
            3) _ferry__files ;;
            *) # ferry parses options from $4 on: parse_opts "${@:4}"
              if [[ $cmd == ship ]]; then
                _ferry__words --force --tag= # fetch parses --tag but never uses it
              else
                _ferry__words --force
              fi
              ;;
          esac
          ;;
        dock)
          case $COMP_CWORD in
            2) _ferry__words north south east ;;
            3) _ferry__words ro rw ;; # required: the script checks $# -eq 3
          esac
          ;;
        status)
          if (( COMP_CWORD == 2 )); then _ferry__words --json; fi # only the literal --json, only as $2
          ;;
      esac
      ;;
  esac

  # --tag= takes its value in the same word: no space after the '='
  if [[ ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == *= ]]; then compopt -o nospace 2>/dev/null; fi
  return 0
}

if type compopt >/dev/null 2>&1; then
  complete -F _ferry ferry
else
  complete -o nospace -F _ferry ferry # bash 3.2: spaces are appended by _ferry__words
fi
