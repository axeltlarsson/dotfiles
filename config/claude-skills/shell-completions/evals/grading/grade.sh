#!/usr/bin/env bash
# grade.sh <ferry|review|theme> <outputs-dir> [final-message.md] [transcript.md]
#
# Objective checks for the skill-creator evals. Prints `PASS|FAIL <n> <text> | <evidence>`
# per expectation (the grader agent maps these onto grading.json). Needs a pty for the
# harness rows: run unsandboxed.
set -uo pipefail
kind=${1:?ferry|review|theme} out=${2:?outputs dir}
final=${3:-/dev/null} transcript=${4:-/dev/null}
here=$(cd "$(dirname "$0")" && pwd)
skill=$(cd "$here/../.." && pwd)
n=0
res() { n=$((n + 1)); printf '%s %d %s | %s\n' "$1" "$n" "$2" "${3:-}"; }
first() { fd -H -t f -g "$1" "$out" 2>/dev/null | head -1; }

harness_rows() { # cmd zf bf cases [--cwd dir]
  local cmd=$1 zf=$2 bf=$3 cases=$4; shift 4
  local tmp; tmp=$(mktemp -d "${TMPDIR:-/tmp}/grade.XXXXXX"); mkdir -p "$tmp/sf"; ln -s "$zf" "$tmp/sf/_$cmd"
  local line
  if "$skill/scripts/check-static.sh" "$zf" "$bf" >"$tmp/static" 2>&1; then res PASS "check-static.sh passes" "$(tail -1 "$tmp/static")"; else res FAIL "check-static.sh passes" "$(grep '^FAIL' "$tmp/static" | head -3 | tr '\n' ';')"; fi
  line=$(zsh "$skill/scripts/test-zsh-completion.zsh" "$tmp/sf" "$cases" "$@" 2>&1 | tail -1)
  [[ $line == *"FAIL 0" ]] && res PASS "grading zsh cases pass" "$line" || res FAIL "grading zsh cases pass" "$line"
  for b in "$(command -v bash)" /bin/bash; do
    [[ -x $b ]] || continue
    line=$(uv run -q "$skill/scripts/test-bash-completion.py" "$bf" "$b" "$cases" "$@" 2>&1 | grep -E '^bash ' | tail -1)
    [[ $line == *"FAIL 0" ]] && res PASS "grading bash cases pass under $b" "$line" || res FAIL "grading bash cases pass under $b" "$line"
  done
  rm -rf "$tmp"
}

evidence_block() { # file(s)
  local c; c=$(cat "$@" 2>/dev/null | grep -cE '^(zsh|bash) [^ ]+  PASS [0-9]+ FAIL 0')
  (( c >= 3 )) && res PASS "quotes the verify evidence block (>= 3 FAIL 0 lines)" "$c lines" || res FAIL "quotes the verify evidence block (>= 3 FAIL 0 lines)" "$c lines"
}

case $kind in
  ferry)
    zf=$(first '_ferry'); bf=$(first 'ferry.bash'); nix=$(first 'flake.nix'); pr=$(first 'PR.md')
    [[ -n $zf && -n $bf ]] || { res FAIL "completion files produced" "zf=$zf bf=$bf"; exit 1; }
    harness_rows ferry "$zf" "$bf" "$here/ferry.cases.tsv" --cwd "$skill/evals/files/ferry/fixtures"
    if [[ -n $nix ]] && grep -qE 'installShellCompletion|share/bash-completion/completions/ferry\.bash' "$nix" && grep -qE '\bmeta\b' "$nix"; then
      res PASS "flake installs share/ files as ferry.bash/_ferry and keeps meta" "$nix"
    else res FAIL "flake installs share/ files as ferry.bash/_ferry and keeps meta" "$nix"; fi
    evidence_block "${pr:-/dev/null}" "$final"
    grep -qiE -- 'fetch.{0,120}--tag|--tag.{0,120}fetch' "${pr:-/dev/null}" "$final" && res PASS "reports fetch ignores --tag" || res FAIL "reports fetch ignores --tag"
    grep -qiE 'dock.{0,160}(requir|mandatory|exact|not optional|\$# -eq 3)' "${pr:-/dev/null}" "$final" && res PASS "reports dock mode is required" || res FAIL "reports dock mode is required"
    grep -qE 'verify\.sh|test-(zsh|bash)-completion|pexpect|zpty' "$transcript" && res PASS "transcript shows a pty harness ran" || res FAIL "transcript shows a pty harness ran"
    ;;
  review)
    rv=$(first 'review.md'); [[ -n $rv ]] || { res FAIL "review.md produced"; exit 1; }
    # keyword pre-check only: the verdict for this row and for 'no harmful advice' comes from the
    # blind semantic grader (keyword hits cannot tell a finding from a recommendation)
    out_g=$("$here/grade-review.py" "$rv" "$here/findings.tsv" 11 2>&1); rc=$?
    (( rc == 0 )) && res PASS "finds >= 11 of 12 planted defects (keyword pre-check)" "$(tail -1 <<<"$out_g")" || res FAIL "finds >= 11 of 12 planted defects (keyword pre-check)" "$(tail -1 <<<"$out_g")"
    grep -qE '(_ferry|ferry\.bash|flake\.nix):[0-9]+' "$rv" && res PASS "cites file:line" || res FAIL "cites file:line"
    grep -qiE 'block|nit|non-blocking|minor' "$rv" && res PASS "separates blockers from nits" || res FAIL "separates blockers from nits"
    grep -qiE '#compdef.{0,60}(missing|absent)' "$rv" && res FAIL "does not claim #compdef is missing" || res PASS "does not claim #compdef is missing"
    res FAIL "gives no harmful advice" "pending: set by the blind semantic grader"
    ;;
  theme)
    zf=$(first '_theme'); bf=$(first 'theme.bash'); nix=$(first 'theme.nix')
    [[ -n $zf && -n $bf ]] || { res FAIL "completion files produced" "zf=$zf bf=$bf"; exit 1; }
    harness_rows theme "$zf" "$bf" "$here/theme.cases.tsv"
    if [[ -n $nix ]] && grep -qE 'installShellCompletion|share/bash-completion/completions/theme\.bash' "$nix" && grep -qE '\bmeta\b' "$nix" && grep -q 'home.packages' "$nix" && grep -q 'launchd' "$nix"; then
      res PASS "theme.nix installs completions, keeps meta and its consumers" "$nix"
    else res FAIL "theme.nix installs completions, keeps meta and its consumers" "$nix"; fi
    if [[ -n $nix ]] && nix run nixpkgs#nixfmt -- --check "$nix" >/dev/null 2>&1; then res PASS "nixfmt --check passes on theme.nix"; else res FAIL "nixfmt --check passes on theme.nix"; fi
    evidence_block "$final" "$(first 'PR.md')" "$(first 'COMMIT*')"
    grep -qE '(darwin-rebuild|home-manager|nixos-rebuild|nh (darwin|os|home)) +switch|nix develop -c +switch|(^|[;&|(] *)switch( |$)' "$transcript" && res FAIL "transcript contains no switch" || res PASS "transcript contains no switch"
    grep -qE '^[^A-Za-z0-9[:space:]]+ [A-Z][a-z]+ .*[Cc]ompletion' "$final" "$(first 'COMMIT*')" && res PASS "commit message is emoji + imperative and mentions completions" || res FAIL "commit message is emoji + imperative and mentions completions"
    grep -qiE '(light|dark|toggle|auto).{0,120}(ignor|silently|extra)' "$final" && res PASS "reports that extra arguments are silently ignored" || res FAIL "reports that extra arguments are silently ignored"
    ;;
  *) echo "unknown kind $kind" >&2; exit 2 ;;
esac
