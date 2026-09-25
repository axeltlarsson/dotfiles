# shellcheck shell=bash
# bash completion for CMD — grammar read from the dispatcher in <script> @ <git sha>
# (grammar table in the PR); verified by CMD.cases.tsv. Literal lists mirror the script.
# Runs on macOS /bin/bash 3.2 (no mapfile, no compopt): the 3.2 branch adds the trailing
# space / directory slash itself; only quoting of special characters in file names is lost.
#
# TEMPLATE NOTES (delete them; keep only comments that cite the CLI, file:line):
# - install as share/bash-completion/completions/CMD.bash (bash-completion ≥ 2.18 name)
# - words/cword below are the shell's words, numbered like the CLI's $N. If flags can precede
#   positionals, walk words[] and skip option words instead of indexing by cword.

# bash 3.2 has no compopt
_CMD__have_compopt() { type compopt >/dev/null 2>&1; }

# The shell's words up to the cursor, in words[]/cword. bash 4+ splits COMP_WORDS at '=', ':' and
# '@' (--tag=x, a file name a:b); 3.2 does not. Glue the pieces back unless whitespace separates them.
_CMD__split() {
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
_CMD__words() {
  local w
  for w in "$@"; do
    [[ $w == "$pre$cur"* ]] || continue
    w=${w#"$pre"}
    if _CMD__have_compopt || [[ $w == *= ]]; then
      COMPREPLY+=("$w")
    else
      COMPREPLY+=("$w ") # bash 3.2: registered with -o nospace, so add the space here
    fi
  done
}

# flags the CLI parses from word 4 on (parse_opts "${@:4}"): skip those already given
_CMD__flags() {
  local w p
  [[ $pre$cur == --*=* ]] && return 0 # the value of --tag=: free text
  for w in "$@"; do
    for p in "${words[@]:4:cword-4}"; do
      [[ ${p%%=*} == "${w%%=*}" ]] && continue 2
    done
    _CMD__words "$w"
  done
}

# file completion, scoped to the branch that needs it: a global `complete -o filenames`
# would turn any candidate matching a directory in cwd into "dir/"
_CMD__files() {
  local f
  if _CMD__have_compopt; then
    compopt -o filenames # readline adds / to directories and quotes special characters
    while IFS= read -r f; do COMPREPLY+=("${f#"$pre"}"); done < <(compgen -f -- "$pre$cur")
  else
    while IFS= read -r f; do
      if [[ -d $f ]]; then COMPREPLY+=("${f#"$pre"}/"); else COMPREPLY+=("${f#"$pre"} "); fi
    done < <(compgen -f -- "$pre$cur")
  fi
}

_CMD() {
  # $2 is the text readline will replace. Never ${COMP_WORDS[COMP_CWORD]}: it is "=" right
  # after --tag= on bash 4+ and the unsplit word on 3.2.
  local cur=${2-} cword pre
  local -a words
  COMPREPLY=()
  _CMD__split
  # $cur starts after '=' / ':' and at '@'; $pre is the rest of the shell word before it
  # (an opening quote is not part of $cur either, but is no split)
  pre=${words[cword]%"$cur"}
  if [[ $pre == [\"\']* ]]; then pre=; fi

  case $cword in
    1) _CMD__words sub1 sub2 sub3 help ;;
    *)
      case ${words[1]} in
        sub1)
          case $cword in
            2) _CMD__words eu us ;;
            3) _CMD__files ;;
            *) _CMD__flags --force --tag= ;; # flags are parsed from $4 on: parse_opts "${@:4}"
          esac
          ;;
        sub2)
          case $cword in
            2) _CMD__words north south ;;
            3) _CMD__words ro rw ;; # required: the script checks $# -eq 3
          esac
          ;;
      esac
      ;;
  esac

  # --tag= takes its value in the same word: no space after the '='
  if [[ ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == *= ]] && _CMD__have_compopt; then
    compopt -o nospace
  fi
  return 0
}

# No global -o filenames/default/bashdefault: they add "/" to look-alike candidates and offer
# files past the last argument. Only 3.2 (no compopt) needs -o nospace, handled above.
if _CMD__have_compopt; then
  complete -F _CMD CMD
else
  complete -o nospace -F _CMD CMD
fi
