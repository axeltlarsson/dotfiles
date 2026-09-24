#!/usr/bin/env bash
# check-static.sh <_cmd> <cmd.bash>
#
# Lints a zsh/bash completion pair and checks the conventions reviewers look for
# (see references/review-checklist.md). Prints PASS/FAIL/WARN per check and
# `static  PASS n FAIL m`; exit 1 on any FAIL.
set -u
zf=${1:?zsh completion file (_cmd)} bf=${2:?bash completion file (cmd.bash)}
pass=0 fail=0
tmpf=$(mktemp "${TMPDIR:-/tmp}/check-static.XXXXXX")
trap 'rm -f "$tmpf"' EXIT
ok() { printf 'PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }
warn() { printf 'WARN %s\n' "$1"; }
has() { grep -qE -- "$1" "$2"; }

# ---- zsh -------------------------------------------------------------------
[[ $(head -c 8 "$zf") == '#compdef' ]] && ok "zsh: first line starts with #compdef" ||
  bad "zsh: first line must be '#compdef <cmd>' (compinit only registers files that start with it)"
zcmd=$(sed -n '1s/^#compdef  *\([^ ]*\).*/\1/p' "$zf")
[[ $(basename "$zf") == "_$zcmd" ]] && ok "zsh: file is named _$zcmd (file name = function name)" ||
  bad "zsh: file must be named _<cmd> to match '#compdef $zcmd'"
zsh -n "$zf" 2>/dev/null && ok "zsh: syntax (zsh -n)" || bad "zsh: syntax error (zsh -n)"
zsh -f -c 'fpath=("$1" $fpath); autoload -Uz "$2" && autoload +X "$2"' -- "$(cd "$(dirname "$zf")" && pwd)" "$(basename "$zf")" 2>/dev/null &&
  ok "zsh: autoload +X loads the function" || bad "zsh: autoload +X fails"
if has '->' "$zf"; then
  has 'local [^#]*curcontext="\$curcontext"' "$zf" && ok "zsh: curcontext localised and initialised" ||
    bad "zsh: -> state used but no 'local curcontext=\"\$curcontext\"' (-C rewrites it)"
  for v in state state_descr line; do
    has "local [^#]*\\b$v\\b" "$zf" && ok "zsh: '$v' is local" || bad "zsh: '$v' must be local (set by _arguments)"
  done
  has 'typeset -A opt_args' "$zf" && ok "zsh: opt_args declared local" || bad "zsh: missing 'typeset -A opt_args'"
fi
has '\bret=1\b' "$zf" && { has 'return ret' "$zf" && ok "zsh: ret idiom (return ret)" || bad "zsh: ret=1 declared but never 'return ret'"; }
has '_values' "$zf" && warn "zsh: _values used — positionals normally belong in _arguments specs so every arm reports 'no more arguments'"
has ":\(+[^)]*[[:space:]\"]--?[a-zA-Z]" "$zf" && warn "zsh: an option-looking word inside a positional word list — only right for a literal the CLI accepts at a fixed position (rule R9); real options must be optspecs"
has 'compadd' "$zf" && ! has '"\$expl\[@\]"|_wanted|_describe' "$zf" && warn "zsh: bare compadd without \"\$expl[@]\"/_wanted"
has '(^|[^_a-zA-Z])(echo|print) ' "$zf" && warn "zsh: prints from the completer — use _message"

# ---- bash ------------------------------------------------------------------
[[ $(head -1 "$bf") == '# shellcheck shell=bash'* ]] && ok "bash: line 1 is '# shellcheck shell=bash'" ||
  bad "bash: line 1 must be '# shellcheck shell=bash' (sourced file, no shebang)"
if command -v shellcheck >/dev/null; then
  shellcheck -S warning "$bf" >/dev/null 2>&1 && ok "bash: shellcheck -S warning" || bad "bash: shellcheck -S warning reports problems"
else
  warn "bash: shellcheck not on PATH (nix run nixpkgs#shellcheck -- -S warning $bf)"
fi
bash -n "$bf" 2>/dev/null && ok "bash: syntax ($(bash -c 'echo bash $BASH_VERSION'))" || bad "bash: syntax error (bash -n)"
if [[ -x /bin/bash ]]; then
  /bin/bash -n "$bf" 2>/dev/null && ok "bash: syntax (/bin/bash $(/bin/bash -c 'echo $BASH_VERSION'))" || bad "bash: syntax error under /bin/bash"
fi
forbidden='\bmapfile\b|\breadarray\b|declare -[a-zA-Z]*A|local -[a-zA-Z]*A|\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^|@[QEPAa])|;;&|\|&|\$\{[A-Za-z_][A-Za-z0-9_]*\[-[0-9]|local -n\b|\[\[ -v '
# comments stripped first so prose like "no mapfile" does not trip it
if sed -E 's/(^|[[:space:]])#.*$//' "$bf" | grep -nE -- "$forbidden" >"$tmpf" 2>/dev/null && [[ -s $tmpf ]]; then
  bad "bash: construct that fails on macOS /bin/bash 3.2: $(head -3 "$tmpf" | tr '\n' ';')"
else
  ok "bash: no bash-4-only constructs (3.2-sourceable)"
fi
if has 'compopt' "$bf"; then
  if has 'type compopt' "$bf" || ! grep -E 'compopt' "$bf" | grep -vqE '2>/dev/null|type compopt'; then
    ok "bash: compopt is guarded (bash 3.2 has none)"
  else
    bad "bash: unguarded compopt (guard with 'type compopt >/dev/null 2>&1' or '2>/dev/null')"
  fi
fi
if grep -E '^[[:space:]]*complete ' "$bf" | grep -qE -- '-o (filenames|default|bashdefault|dirnames|plusdirs)'; then
  bad "bash: global 'complete -o filenames/default/...' (turns any candidate matching a cwd dir into 'dir/', offers files past the last argument) — scope with compopt inside the function"
else
  ok "bash: complete line has no global -o filenames/default"
fi
if grep -E '^[[:space:]]*complete ' "$bf" | grep -qE -- '-o nospace' && ! has 'type compopt' "$bf"; then
  bad "bash: global -o nospace without a compopt-availability branch removes the space after every word"
fi
has 'complete .*-F ' "$bf" && ok "bash: registers with complete -F" || bad "bash: no 'complete -F <fn> <cmd>' line"
has 'COMPREPLY=\(\)' "$bf" && ok "bash: COMPREPLY reset" || bad "bash: COMPREPLY=() missing (stale candidates leak between calls)"
has 'cur=\$\{?2' "$bf" && ok "bash: cur comes from \$2 (readline's word)" ||
  warn "bash: cur not taken from \$2 — \${COMP_WORDS[COMP_CWORD]} is '=' right after --opt= on bash 4+ and unsplit on 3.2"
has 'compgen -W "\$' "$bf" && warn "bash: compgen -W \"\$var\" re-expands \$(...) and \${...} inside the words — prefer a literal loop"
has 'COMPREPLY=\( *\$\(' "$bf" && warn "bash: COMPREPLY=( \$(...) ) word-splits and globs (SC2207)"
has '(^|[^_a-zA-Z])(echo|printf) ' "$bf" && ! has '(echo|printf) [^#]*>&2' "$bf" && warn "bash: prints to stdout from the completer"

printf 'static  PASS %d FAIL %d\n' "$pass" "$fail"
(( fail == 0 ))
