# shellcheck shell=bash
# bash completion for CMD — grammar read from the dispatcher in <script> @ <git sha>
# (grammar table in the PR); verified by CMD.cases.tsv. Literal lists mirror the script.
# Runs on macOS /bin/bash 3.2 (no mapfile, no compopt): the 3.2 branch adds the trailing
# space / directory slash itself; only quoting of special characters in file names is lost.
#
# TEMPLATE NOTES (delete them; keep only comments that cite the CLI, file:line):
# - install as share/bash-completion/completions/CMD.bash (bash-completion ≥ 2.18 name)
# - COMP_CWORD == N is the CLI's $N only while every earlier word is a positional. If flags
#   can precede positionals, walk COMP_WORDS and skip option words (and the '=' pieces
#   bash 4+ splits them into) instead of indexing by COMP_CWORD.

_CMD__have_compopt() { type compopt >/dev/null 2>&1; }

# offer every word matching $cur; skip options already on the line (zsh does this natively)
_CMD__words() {
  local w p
  for w in "$@"; do
    [[ $w == "$cur"* ]] || continue
    if [[ $w == -* ]]; then
      for p in "${COMP_WORDS[@]:4:COMP_CWORD-4}"; do # 4 = first word the CLI parses flags from
        [[ ${p%%=*} == "${w%%=*}" ]] && continue 2
      done
    fi
    if _CMD__have_compopt || [[ $w == *= ]]; then
      COMPREPLY+=("$w")
    else
      COMPREPLY+=("$w ") # bash 3.2: registered with -o nospace, so add the space here
    fi
  done
}

# file completion, scoped to the branch that needs it: a global `complete -o filenames`
# would turn any candidate matching a directory in cwd into "dir/"
_CMD__files() {
  local f
  if _CMD__have_compopt; then
    compopt -o filenames # readline adds / to directories and quotes special characters
    while IFS= read -r f; do COMPREPLY+=("$f"); done < <(compgen -f -- "$cur")
  else
    while IFS= read -r f; do
      if [[ -d $f ]]; then COMPREPLY+=("$f/"); else COMPREPLY+=("$f "); fi
    done < <(compgen -f -- "$cur")
  fi
}

_CMD() {
  # $2 is the word readline will replace. Never ${COMP_WORDS[COMP_CWORD]}: it is "=" right
  # after --opt= on bash 4+ (COMP_WORDBREAKS) and the unsplit word on 3.2.
  local cur=${2-} cmd=${COMP_WORDS[1]-} lw
  COMPREPLY=()
  # --opt=value in one word: bash 4+ splits it into COMP_WORDS, 3.2 does not — read the line
  lw=${COMP_LINE:0:COMP_POINT}
  lw=${lw##*[[:space:]]}
  if [[ $lw == --*=* ]]; then return 0; fi # value of --tag=: free text, nothing to offer

  case $COMP_CWORD in
    1) _CMD__words sub1 sub2 help ;;
    *)
      case $cmd in
        sub1)
          case $COMP_CWORD in
            2) _CMD__words eu us ;;
            3) _CMD__files ;;
            *) _CMD__words --force --tag= ;; # flags are parsed from $4 on: parse_opts "${@:4}"
          esac
          ;;
        sub2)
          case $COMP_CWORD in
            2) _CMD__words north south ;;
            3) _CMD__words ro rw ;; # required: the script checks $# -eq 3
          esac
          ;;
      esac
      ;;
  esac

  # --tag= takes its value in the same word: no space after the '='
  if [[ ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == *= ]]; then compopt -o nospace 2>/dev/null; fi
  return 0
}

# No global -o filenames/default/bashdefault: they add "/" to look-alike candidates and offer
# files past the last argument. Only 3.2 (no compopt) needs -o nospace, handled above.
if type compopt >/dev/null 2>&1; then
  complete -F _CMD CMD
else
  complete -o nospace -F _CMD CMD
fi
