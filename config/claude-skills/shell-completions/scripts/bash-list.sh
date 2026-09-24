# shellcheck shell=bash
# bash-list.sh <completion-file> <cmd> <line>
#
# Run under the bash you want to test, e.g.
#   /bin/bash --noprofile --norc bash-list.sh ferry.bash ferry 'ferry ship eu '
# Sources the file, rebuilds COMP_WORDS/COMP_CWORD/$2/$3 the way readline would for
# this bash version (>= 4 also splits words at '=' and ':'; 3.2 does not), calls the
# registered function and prints COMPREPLY one candidate per line.
# Deliberately bash 3.2 compatible.
file=$1 cmd=$2 line=$3
# shellcheck disable=SC1090
source "$file" || exit 3
spec=$(complete -p -- "$cmd" 2>/dev/null) || { echo "no compspec registered for $cmd" >&2; exit 3; }
fn=${spec##*-F }
fn=${fn%% *}

# whitespace tokens; a trailing space opens a new, empty word
toks=()
read -ra toks <<<"$line"
case $line in *[[:space:]]) toks+=("") ;; esac
(( ${#toks[@]} )) || toks=("")

words=()
if (( BASH_VERSINFO[0] >= 4 )); then
  for orig in "${toks[@]}"; do
    if [[ -z $orig ]]; then
      words+=("")
      continue
    fi
    t=$orig
    while [[ $t == *[=:]* ]]; do
      pre=${t%%[=:]*}
      [[ -n $pre ]] && words+=("$pre")
      words+=("${t:${#pre}:1}")
      t=${t:$(( ${#pre} + 1 ))}
    done
    [[ -n $t ]] && words+=("$t")
  done
else
  words=("${toks[@]}")
fi

last=${toks[${#toks[@]}-1]}
cur=${last##*[=:]} # readline's $2: the text after the last word-break character
prev=
if (( BASH_VERSINFO[0] >= 4 )); then
  (( ${#words[@]} >= 2 )) && prev=${words[${#words[@]}-2]}
else
  (( ${#toks[@]} >= 2 )) && prev=${toks[${#toks[@]}-2]}
fi

COMP_WORDS=("${words[@]}")
COMP_CWORD=$(( ${#words[@]} - 1 ))
COMP_LINE=$line
COMP_POINT=${#line}
COMP_KEY=9
COMP_TYPE=9
COMPREPLY=()
"$fn" "$cmd" "$cur" "$prev" 2>/dev/null
for r in "${COMPREPLY[@]}"; do printf '%s\n' "$r"; done
