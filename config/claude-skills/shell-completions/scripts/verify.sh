#!/usr/bin/env bash
# verify.sh <cmd> <_cmd> <cmd.bash> <cases.tsv> [--cwd DIR]
#
# The whole verification in one go: static checks, the zsh pty harness, the bash
# harness under the bash on PATH and under /bin/bash (3.2 on macOS). Prints every
# PASS/FAIL line, then an evidence block to paste into the PR:
#   static  PASS n FAIL m
#   zsh 5.9.2  PASS n FAIL m
#   bash 5.3.15  PASS n FAIL m
#   bash 3.2.57  PASS n FAIL m
# Exit 1 if anything failed. Needs a pty: run unsandboxed.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
cmd=${1:?cmd} zf=${2:?_cmd} bf=${3:?cmd.bash} cases=${4:?cases.tsv}
shift 4
cwdargs=()
[[ ${1-} == --cwd ]] && cwdargs=(--cwd "${2:?dir}")
zf=$(cd "$(dirname "$zf")" && pwd)/$(basename "$zf")
bf=$(cd "$(dirname "$bf")" && pwd)/$(basename "$bf")
tmp=$(mktemp -d "${TMPDIR:-/tmp}/verify.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site-functions"
ln -s "$zf" "$tmp/site-functions/_$cmd"
log=$tmp/log
rc=0

echo "## static"
"$here/check-static.sh" "$zf" "$bf" | tee -a "$log" || rc=1
# the three shells run concurrently; each harness also runs its cases in parallel
zsh "$here/test-zsh-completion.zsh" "$tmp/site-functions" "$cases" "${cwdargs[@]}" >"$tmp/h1" 2>&1 &
p1=$!
uv run -q "$here/test-bash-completion.py" "$bf" "$(command -v bash)" "$cases" "${cwdargs[@]}" >"$tmp/h2" 2>&1 &
p2=$!
p3=
if [[ -x /bin/bash ]]; then
  uv run -q "$here/test-bash-completion.py" "$bf" /bin/bash "$cases" "${cwdargs[@]}" >"$tmp/h3" 2>&1 &
  p3=$!
fi
wait "$p1" || rc=1
wait "$p2" || rc=1
if [[ -n $p3 ]]; then wait "$p3" || rc=1; fi
echo "## zsh"; tee -a "$log" <"$tmp/h1"
echo "## $(command -v bash)"; tee -a "$log" <"$tmp/h2"
if [[ -n $p3 ]]; then echo "## /bin/bash"; tee -a "$log" <"$tmp/h3"; fi

echo "## controls"
# a deliberately wrong expectation has to FAIL, or the harness is not asserting anything
ctl=$tmp/controls.tsv
printf 'id\tshell\tline\tassert\texpect\tbash32\tnotes\nC.fail\tboth\t%s{sp}\tset_eq\tno-such-candidate-xyz\tsame\twrong expectation\n' "$cmd" >"$ctl"
cpass=0 cfail=0
if zsh "$here/test-zsh-completion.zsh" "$tmp/site-functions" "$ctl" "${cwdargs[@]}" >/dev/null 2>&1; then
  echo "FAIL C.zsh  the zsh harness accepted a wrong expectation"; cfail=$((cfail + 1))
else
  echo "PASS C.zsh  the zsh harness rejects a wrong expectation"; cpass=$((cpass + 1))
fi
if uv run -q "$here/test-bash-completion.py" "$bf" "$(command -v bash)" "$ctl" "${cwdargs[@]}" >/dev/null 2>&1; then
  echo "FAIL C.bash  the bash harness accepted a wrong expectation"; cfail=$((cfail + 1))
else
  echo "PASS C.bash  the bash harness rejects a wrong expectation"; cpass=$((cpass + 1))
fi
printf 'controls  PASS %d FAIL %d\n' "$cpass" "$cfail" | tee -a "$log"
(( cfail == 0 )) || rc=1

echo
echo "## evidence"
grep -E '^(static|zsh|bash|controls)( [^ ]+)?  PASS [0-9]+ FAIL [0-9]+$' "$log"
exit $rc
