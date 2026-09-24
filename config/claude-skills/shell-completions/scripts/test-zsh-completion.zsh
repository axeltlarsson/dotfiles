#!/usr/bin/env zsh
# test-zsh-completion.zsh <site-functions-dir> <cases.tsv> [--cwd DIR]
#
# Drives real zsh completion in a pty (zpty), one fresh `zsh -f -i` per case, and
# asserts on the matches compsys added, the messages it showed and the resulting
# line buffer (captured by harness.zshrc, not scraped from the screen).
# Rows: id  shell(zsh|bash|both)  line  assert  expect  bash32  notes  ("{sp}" = space).
# Asserts: set_eq set_empty set_has set_not buf buf_unchanged msg msg_not.
# Prints PASS/FAIL per case and `zsh <version>  PASS n FAIL m`; exit 1 on any failure.
# Needs a pty: run unsandboxed.
emulate -L zsh
setopt extendedglob
zmodload zsh/zpty

local dir=${1:?site-functions dir} cases=${2:?cases.tsv}
shift 2
local cwd=$PWD
while (( $# )); do
  case $1 in
    --cwd) cwd=${2:A}; shift 2 ;;
    *) print -u2 -- "unknown argument: $1"; exit 2 ;;
  esac
done
dir=${dir:A}
local here=${0:A:h}
local tmp
tmp=$(mktemp -d "${TMPDIR:-/tmp}/zshcomp.XXXXXX") || exit 2
local pass=0 fail=0

typeset -ga got_list got_msgs
typeset -g got_buf

complete_once() { # id line
  local id=$1 line=$2 cap=$tmp/$1.cap out buf= i
  : >"$cap"
  zpty -b z env -i HOME="$HOME" PATH="$PATH" TERM=xterm-256color COLUMNS=200 LINES=50 \
    COMPLETION_DIR="$dir" CAP_FILE="$cap" zsh -f -i
  # zle emits bracketed-paste-on each time it starts reading a line. Anything written
  # before that is flushed by the terminal re-init, so wait for it before every write.
  local zle_ready=$'\e[?2004h'
  for i in {1..200}; do
    zpty -r -t z out 2>/dev/null && buf+=$out
    [[ $buf == *${zle_ready}* ]] && break
    sleep 0.05
  done
  zpty -w z "cd ${(q)cwd} && source ${(q)here}/harness.zshrc"
  for i in {1..300}; do
    zpty -r -t z out 2>/dev/null && buf+=$out
    [[ $buf == *READY*${zle_ready}* ]] && break
    sleep 0.05
  done
  zpty -w -n z "${line}"$'\t'
  for i in {1..200}; do
    [[ -s $cap ]] && grep -q '^END$' "$cap" && break
    sleep 0.05
  done
  zpty -d z 2>/dev/null
  got_list=() got_msgs=() got_buf=
  local l
  for l in "${(f)$(<$cap)}"; do
    case $l in
      LIST:*) got_list=("${(@s:|:)${l#LIST:}}") ;;
      MSG:*) got_msgs=("${(@s:|:)${l#MSG:}}") ;;
      BUF:*) got_buf=${${l#BUF:<}%>} ;;
    esac
  done
  got_list=(${got_list:#})
  got_msgs=(${got_msgs:#})
  [[ $buf == *READY* ]] || print -u2 -- "  warning: $id: child never printed READY"
}

check() { # id line assert expect notes
  local id=$1 line=$2 assert=$3 expect=$4 notes=$5 ok=0 detail e
  local -a exp
  [[ $expect == - ]] || exp=("${(@s:|:)expect}")
  exp=(${exp:#})
  local sgot=${(j:|:)${(o)got_list}} sexp=${(j:|:)${(o)exp}} smsg=${(j:|:)got_msgs}
  case $assert in
    set_eq) [[ $sgot == "$sexp" ]] && ok=1; detail="list=[$sgot]" ;;
    set_empty) (( ${#got_list} == 0 )) && ok=1; detail="list=[$sgot]" ;;
    set_has) ok=1; for e in $exp; do (( ${got_list[(Ie)$e]} )) || ok=0; done; detail="list=[$sgot]" ;;
    set_not) ok=1; for e in $exp; do (( ${got_list[(Ie)$e]} )) && ok=0; done; detail="list=[$sgot]" ;;
    buf) [[ $got_buf == "$expect" ]] && ok=1; detail="buf=<$got_buf>" ;;
    buf_unchanged) [[ $got_buf == "$line" ]] && ok=1; detail="buf=<$got_buf>" ;;
    msg) [[ $smsg == *"$expect"* ]] && ok=1; detail="msgs=[$smsg]" ;;
    msg_not) [[ $smsg != *"$expect"* ]] && ok=1; detail="msgs=[$smsg]" ;;
    *) detail="unknown assert '$assert'" ;;
  esac
  if (( ok )); then
    print -r -- "PASS $id  $notes"
    (( pass++ )) || true
  else
    print -r -- "FAIL $id  $notes"
    print -r -- "     typed: <$line>  assert: $assert  expect: [$expect]  $detail"
    (( fail++ )) || true
  fi
}

local raw
local -a f
while IFS= read -r raw; do
  [[ -z $raw || $raw == \#* || $raw == id$'\t'* ]] && continue
  f=("${(@ps:\t:)raw}")
  [[ $f[2] == (zsh|both) ]] || continue
  local line=${f[3]//\{sp\}/ } expect=${f[5]//\{sp\}/ }
  complete_once "$f[1]" "$line"
  check "$f[1]" "$line" "$f[4]" "${expect:--}" "${f[7]-}"
done <"$cases"

rm -rf "$tmp"
print -r -- "zsh $ZSH_VERSION  PASS $pass FAIL $fail"
(( fail == 0 ))
