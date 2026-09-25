# shellcheck shell=bash
# bash completion for publish-report — grammar read from the argparse parser in
# config/claude-skills/publish-report/publish_report.py @ 176cec0; verified by
# publish-report.cases.tsv. config/publish-report.nix fails the build when the options drift.
# Must stay sourceable by macOS /bin/bash 3.2: no compopt, mapfile or declare -A.

_publish_report__have_compopt() { type compopt >/dev/null 2>&1; }

# The shell's words up to the cursor, in words[]/cword. bash 4+ splits COMP_WORDS at '=', ':' and
# '@' (--name=x, a file name a:b); 3.2 does not. Glue the pieces back unless whitespace separates them.
_publish_report__split() {
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

# offer every word matching the whole current word; readline replaces only $cur, so strip $pre
_publish_report__words() {
  local w
  for w in "$@"; do
    [[ $w == "$pre$cur"* ]] || continue
    w=${w#"$pre"}
    if _publish_report__have_compopt || [[ $w == *= ]]; then
      COMPREPLY+=("$w")
    else
      COMPREPLY+=("$w ") # bash 3.2: registered with -o nospace
    fi
  done
}

# main() rejects anything but an existing .html/.htm file (suffix compared lowercased)
_publish_report__files() {
  local f q
  while IFS= read -r f; do
    [[ -d $f || $f == *.[hH][tT][mM] || $f == *.[hH][tT][mM][lL] ]] || continue
    if _publish_report__have_compopt; then
      COMPREPLY+=("${f#"$pre"}")
    else
      printf -v q '%q' "${f#"$pre"}" # no -o filenames on 3.2: quote the name ourselves
      if [[ -d $f ]]; then COMPREPLY+=("$q/"); else COMPREPLY+=("$q "); fi
    fi
  done < <(compgen -f -- "$pre$cur")
  if _publish_report__have_compopt; then compopt -o filenames; fi
}

_publish_report() {
  local cur=${2-} cword pre i w o dashdash='' file='' value='' seen=' '
  local -a words
  COMPREPLY=()
  _publish_report__split
  pre=${words[cword]%"$cur"}
  if [[ $pre == [\"\']* ]]; then pre=; fi

  # argparse: options anywhere, --prefix/--name take `v` or `=v`, `--` ends options
  for ((i = 1; i < cword; i++)); do
    w=${words[i]}
    if [[ -n $value ]]; then
      value=
    elif [[ -z $dashdash && $w == -?* ]]; then
      case ${w%%=*} in
        --) dashdash=1 ;;
        -h | --help) return 0 ;;
        --prefix | --name) [[ $w == *=* ]] || value=1 ;;
      esac
      seen="$seen${w%%=*} "
    else
      file=1
    fi
  done

  if [[ -n $value ]]; then
    : # free-text value of --prefix/--name
  elif [[ -z $dashdash && ($pre$cur == -* || (-n $file && -z $pre$cur)) ]]; then
    [[ $pre$cur == *=* ]] && return 0
    for o in -h --help --prefix= --name= --no-invalidate; do
      [[ $seen == *" ${o%=} "* ]] || _publish_report__words "$o"
    done
  elif [[ -z $file ]]; then
    _publish_report__files
  fi

  # --prefix=/--name= take their value in the same word: no space after the '='
  if [[ ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == *= ]] && _publish_report__have_compopt; then
    compopt -o nospace
  fi
  return 0
}

# No global -o filenames/default/bashdefault: they add "/" to look-alike candidates and offer
# files past the positional. Only 3.2 (no compopt) needs -o nospace, handled above.
if _publish_report__have_compopt; then
  complete -F _publish_report publish-report
else
  complete -o nospace -F _publish_report publish-report
fi
