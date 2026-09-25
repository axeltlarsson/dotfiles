#!/usr/bin/env bash
# verify.sh <cmd> <_cmd> <cmd.bash> <cases.tsv> [--cwd DIR] [--verbose]
#
# The whole verification in one go: static checks, the zsh pty harness, the bash harness
# under an interactive bash 4+ and under /bin/bash (3.2 on macOS). Preflight checks fail in
# about a second when the environment cannot run the harnesses (sandboxed pty or network, no
# line-editing bash); each harness has a watchdog (VERIFY_TIMEOUT, default 120 s). Prints FAIL
# and WARN lines (all lines with --verbose; full log in $TMPDIR/verify-<cmd>.log) and ends with
# the evidence block to paste into the PR:
#   static  PASS n FAIL m
#   zsh 5.9.2  PASS n FAIL m
#   bash 5.3.15(1)-release  PASS n FAIL m
#   bash 3.2.57(1)-release  PASS n FAIL m
#   controls  PASS 2 FAIL 0
# Exit 1 if anything failed, 2 if the environment cannot run the harnesses.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
cmd=${1:?cmd} zf=${2:?_cmd} bf=${3:?cmd.bash} cases=${4:?cases.tsv}
shift 4
cwdargs=() verbose=
while (($#)); do
  case $1 in
    --cwd) cwdargs=(--cwd "${2:?dir}"); shift 2 ;;
    --verbose) verbose=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
zf=$(cd "$(dirname "$zf")" && pwd)/$(basename "$zf")
bf=$(cd "$(dirname "$bf")" && pwd)/$(basename "$bf")
cases=$(cd "$(dirname "$cases")" && pwd)/$(basename "$cases")
limit=${VERIFY_TIMEOUT:-120}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/verify.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
log=${TMPDIR:-/tmp}/verify-$cmd.log
: >"$log"
die() { printf 'PREFLIGHT FAIL: %s\n' "$1" >&2; exit 2; }

# ---- preflight: each check is quick and names the fix ----------------------------------
command -v zsh >/dev/null || die "zsh not on PATH"
command -v uv >/dev/null || die "uv not on PATH (the bash harness is a PEP 723 script: nix run nixpkgs#uv)"
python3 -c 'import os, pty; m, s = pty.openpty(); os.close(m); os.close(s)' 2>/dev/null ||
  die "cannot open a pseudo-terminal — the sandbox denies ptys: run verify.sh unsandboxed"
# a bash with readline and programmable completion; inside a nix devShell `bash` is stdenv's
# minimal build without a line editor, where TAB does nothing
interactive() { "$1" --noprofile --norc -c 'shopt -q progcomp 2>/dev/null && type bind >/dev/null 2>&1 && ((BASH_VERSINFO[0] >= 4))' 2>/dev/null; }
bash4=
for b in ${BASH_INTERACTIVE-} /run/current-system/sw/bin/bash "/etc/profiles/per-user/${USER-}/bin/bash" "$HOME/.nix-profile/bin/bash" $(type -ap bash); do
  [[ -x $b ]] && interactive "$b" && { bash4=$b; break; }
done
if [[ -z $bash4 ]] && command -v nix >/dev/null; then
  b=$(nix build --no-link --print-out-paths nixpkgs#bashInteractive 2>/dev/null)/bin/bash
  [[ -x $b ]] && interactive "$b" && bash4=$b
fi
[[ -n $bash4 ]] || die "no bash >= 4 with readline found (set BASH_INTERACTIVE=/path/to/bash)"
bash3=
if [[ -x /bin/bash ]] && /bin/bash --noprofile --norc -c '((BASH_VERSINFO[0] < 4))' 2>/dev/null; then bash3=/bin/bash; fi
# first run downloads pexpect; a sandboxed network makes uv retry for minutes, so bound it
( uv run -q --no-project --with pexpect python3 -c 'import pexpect' >/dev/null 2>&1 ) & p=$!
for _ in $(seq 1 60); do kill -0 $p 2>/dev/null || break; sleep 1; done
if kill -0 $p 2>/dev/null; then kill $p 2>/dev/null; die "uv could not provide pexpect within 60 s (offline or sandboxed network?)"; fi
wait $p || die "uv could not provide pexpect (offline or sandboxed network?)"
printf 'preflight: pty ok, bash %s, %s\n' "$bash4" "${bash3:+bash 3 $bash3}${bash3:-no bash 3.x (not macOS): 3.2 rows skipped}" | tee -a "$log"

mkdir -p "$tmp/site-functions"
ln -s "$zf" "$tmp/site-functions/_$cmd"
rc=0

# run "$@" in the background with the watchdog; output to $1's log file
bounded() { # name outfile cmd...
  local name=$1 out=$2 i; shift 2
  "$@" >"$out" 2>&1 &
  local p=$!
  for ((i = 0; i < limit * 10; i++)); do kill -0 $p 2>/dev/null || break; sleep 0.1; done
  if kill -0 $p 2>/dev/null; then
    pkill -P $p 2>/dev/null; kill $p 2>/dev/null
    printf 'TIMEOUT %s after %ss — a completion function that blocks, or a loaded machine (rerun with COMPLETION_JOBS=1)\n' "$name" "$limit" >>"$out"
    return 1
  fi
  wait $p
}
show() { # file
  tee -a "$log" <"$1" | if [[ -n $verbose ]]; then cat; else grep -E '^(FAIL|WARN|TIMEOUT|     )' || true; fi
}

echo "## static"
"$here/check-static.sh" "$zf" "$bf" >"$tmp/h0" 2>&1 || rc=1
show "$tmp/h0"
bounded zsh "$tmp/h1" zsh "$here/test-zsh-completion.zsh" "$tmp/site-functions" "$cases" "${cwdargs[@]}" &
p1=$!
bounded "bash $bash4" "$tmp/h2" uv run -q "$here/test-bash-completion.py" "$bf" "$bash4" "$cases" "${cwdargs[@]}" &
p2=$!
p3=
if [[ -n $bash3 ]]; then
  bounded "bash $bash3" "$tmp/h3" uv run -q "$here/test-bash-completion.py" "$bf" "$bash3" "$cases" "${cwdargs[@]}" &
  p3=$!
fi
wait "$p1" || rc=1
wait "$p2" || rc=1
if [[ -n $p3 ]]; then wait "$p3" || rc=1; fi
echo "## zsh"; show "$tmp/h1"
echo "## $bash4"; show "$tmp/h2"
if [[ -n $p3 ]]; then echo "## $bash3"; show "$tmp/h3"; fi

# a deliberately wrong expectation has to FAIL, or the harness is not asserting anything
ctl=$tmp/controls.tsv
printf 'id\tshell\tline\tassert\texpect\tbash32\tnotes\nC.fail\tboth\t%s{sp}\tset_eq\tno-such-candidate-xyz\tsame\twrong expectation\n' "$cmd" >"$ctl"
cpass=0 cfail=0
if zsh "$here/test-zsh-completion.zsh" "$tmp/site-functions" "$ctl" "${cwdargs[@]}" >/dev/null 2>&1; then
  echo "FAIL C.zsh  the zsh harness accepted a wrong expectation" | tee -a "$log"; cfail=$((cfail + 1))
else cpass=$((cpass + 1)); fi
if uv run -q "$here/test-bash-completion.py" "$bf" "$bash4" "$ctl" "${cwdargs[@]}" >/dev/null 2>&1; then
  echo "FAIL C.bash  the bash harness accepted a wrong expectation" | tee -a "$log"; cfail=$((cfail + 1))
else cpass=$((cpass + 1)); fi
printf 'controls  PASS %d FAIL %d\n' "$cpass" "$cfail" >>"$log"
((cfail == 0)) || rc=1

echo
echo "## evidence (full log: $log)"
grep -E '^(static|zsh|bash|controls)( [^ ]+)?  PASS [0-9]+ FAIL [0-9]+$|^TIMEOUT' "$log"
exit $rc
