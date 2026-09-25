# Review checklist — what Copilot and Claude-run reviews flag on completion PRs

Severity: **S1** wrong or misleading completion, or breaks a shell (blocks) · **S2** convention /
robustness a strict reviewer always raises · **S3** nit that still draws a comment.
Detection: *static* (`scripts/check-static.sh` or a grep) · *case* (a `cases.tsv` row, typed text ⇒
assertion). Items marked ★ are the ones reviewers flag most often.

## Grammar fidelity (both shells)

- **G1 S1 ★** Flags offered only from the word the CLI parses them (`"${@:4}"` ⇒ zsh `CURRENT > 3`,
  bash `COMP_CWORD ≥ 4`). Optspecs are position-independent. *case*: `cmd sub -` ⇒ `set_empty`;
  `cmd sub a b -` ⇒ the flags.
- **G2 S1 ★** A flag a handler ignores in a branch is not offered there (`ferry fetch` parses
  `--tag` and never reads it). *case*: `set_eq` without it + a positive control in the branch that
  does consume it (`ferry ship`).
- **G3 S1 ★** Value form matches the parser: same-word only ⇒ `--opt=-` and no space after `=`;
  next-word ⇒ `--opt`; both ⇒ `--opt=`. *case*: `buf` `…--opt=` (no `{sp}`); zsh `msg_not` for the
  next-word form.
- **G4 S1** Every literal set equals the CLI's set per position (`set_eq`, never `set_has`). Add a CI
  diff against the script's array (`assets/package.nix.md`).
- **G5 S1** Exact arity ⇒ nothing past the last position (`shell a b <TAB>` ⇒ `set_empty`; zsh
  `msg` "no more arguments"). No `-o default`/`bashdefault`.
- **G6 S2** Conditional positionals gated on the earlier word (a value that exists only after one
  particular first value), optional ones declared optional (`'k::…'`).
- **G7 S2** A `-`-literal accepted only at a fixed `$N` is a positional with a description, not an
  optspec (`[ "${2:-}" = --json ]`). *case*: `ferry status -` ⇒ `--json`; `ferry status --json -` ⇒
  empty.
- **G8 S2** Required-but-unused positionals are still offered; the gap goes in the PR.
- **G9 S2** Default arm: offer the named default word (`${1-help}`), never `-h/--help` fall-throughs.
- **G10 S2** Stubs that exit 0 are offered with "(not yet implemented)"; rejected values never.
- **G11 S2** File constraints mirror the CLI's test (`[ -f ]` ⇒ any file; no `-g` unless filtered).
- **G12 S2** Grammar pinned to the script's SHA in the PR and both file headers.
- **G13 S3 ★** No dynamic lookups at completion time; literal lists are the accepted trade-off
  (state it, add the CI diff).
- **G14 S3** Already-present idempotent flags are not re-offered (zsh: automatic; bash: filter).
- **G15 S3** Help-vs-code drift recorded in the PR; the completion follows the code.

## zsh (`_cmd`)

- **Z1 S1** `#compdef cmd` is bytes 0–7 of line 1; file named `_cmd`; `zsh -n` and `autoload +X` pass.
- **Z2 S1 ★** Options never inside a positional word list (`'*:option:(--a --b=)'`): trailing space,
  no descriptions, no exclusion. Only G7 literals may be positionals.
- **Z3 S1 ★** `=-` vs `=` per G3.
- **Z4 S1 ★** Every arm ends consistently: one `_arguments "${specs[@]}"` per subcommand (says "no
  more arguments"); no `_values` for positionals (returns 0 silently with no matches).
- **Z5 S2 ★** `local curcontext="$curcontext" context state state_descr line ret=1; typeset -A opt_args`
  — the manual's full list; `context` and `state_descr` are the two most often forgotten.
- **Z6 S2** `ret` idiom: `&& ret=0` after every helper, `return ret`.
- **Z7 S2** Per-subcommand `curcontext="${curcontext%:*:*}:cmd-$words[1]:"`.
- **Z8 S2** Descriptions on every value (`((v\:"desc"))`) and every command (`_describe`); lowercase,
  imperative, no trailing period, colons escaped.
- **Z9 S2** Dual-mode footer with **both** checks: `[[ $funcstack[1] == _cmd ]]` and
  `(( $+functions[compdef] ))`; or body-style file. A definition alone never runs on the first TAB.
- **Z10 S2** `*::` shift used; no `$words[N]` guesses, no `$#words`.
- **Z11 S2** `_message` for free text and for `help`/unknown arms; no `_files` for a free name.
- **Z12 S3** `_files` without `-g` unless the CLI filters; comment cites the `[ -f ]` line.
- **Z13 S3** No `print`/`echo`, no `setopt`/`zstyle`/`compdef`/`compinit` in the body.
- **Z14 S3** Helpers prefixed `_cmd_`; never a core-function name.
- **Z15 S3** `-s` only with single-letter options; `-S` only if the CLI honours `--`; `-A '-*'` only
  for options-before-positionals CLIs; no `-V`/`nosort` unless order is semantic.
- **Z16 S3** Quote `"$words[1]"` in `case`/`[[` where Copilot might comment; `# vim: ft=zsh` since
  the file has no extension.

## bash (`cmd.bash`)

- **B1 S1** Same gates as zsh (G1, G2, G5, G6, G7).
- **B2 S1 ★** `compopt -o nospace` only when the unique candidate ends in `=`; never a global
  `-o nospace` on modern bash.
- **B3 S1 ★** `compopt -o filenames` only in the branch that ran `compgen -f`, only at the file's
  index; never `complete -o filenames` (turns `db` into `db/` when a `db` dir exists).
- **B4 S1 ★** Sourceable on `/bin/bash` 3.2: no `mapfile`/`readarray`, `declare -A`, `${x,,}`,
  `;&`, `|&`, `[[ -v`, negative indices, `local -n`; `compopt` guarded; `/bin/bash -n` passes; run
  the harness under `/bin/bash`; the 3.2 branch quotes file names itself (`printf %q`), or a name
  with a space is inserted as several arguments.
- **B5 S1** `complete -F _cmd cmd` with no global `-o default|bashdefault|filenames|dirnames`.
- **B6 S1** `cur=$2` (readline's word), `--opt=value` detected from `COMP_LINE`/`COMP_POINT`; not
  `${COMP_WORDS[COMP_CWORD]}` (it is `=` after `--opt=` on ≥ 4 and unsplit on 3.2).
- **B7 S2** `COMPREPLY=()` first; no `compgen -W "$var"` (re-expands `$(…)`); no
  `COMPREPLY=( $(…) )` (SC2207); `--` before `"$cur"`; `local` everything; `${x-}`.
- **B8 S2** Already-present flags filtered (`${w%%=*}` comparison over the words after the flag start).
- **B9 S2** Positional index by `COMP_CWORD` only while flags are strictly trailing; otherwise a scan
  that skips option words and the `=` pieces bash ≥ 4 splits them into.
- **B10 S2** Installed name `share/bash-completion/completions/cmd.bash` (2.18 deprecates unsuffixed).
- **B11 S2** Every `compopt` guarded (`type compopt >/dev/null 2>&1` or `2>/dev/null`) with a
  comment saying why; `2>/dev/null` nowhere else.
- **B12 S3** `# shellcheck shell=bash` on line 1, no shebang, `shellcheck -S warning` clean with no
  `disable` directives; one `case` arm per line; every numeric gate commented with `file:line`.
- **B13 S3** Never print from the function; no `sudo`/mid-word-cursor claims beyond what is tested.

## Nix / packaging

- **N1 S1** Exact paths and names: `share/zsh/site-functions/_cmd`, `share/bash-completion/completions/cmd.bash`,
  mode 0644 (`installShellCompletion --cmd cmd` does both).
- **N2 S1** The wrapped derivation is what consumers get (`devShells.*.packages`, `home.packages`,
  `packages.<system>.cmd` if `nix run` matters).
- **N3 S1** Completion files tracked by git before `nix build` (flakes ignore untracked files).
- **N4 S2 ★** `meta` (and `passthru`) survive the wrapper: `meta = app.meta` on `runCommand`/`symlinkJoin`.
- **N5 S2** Default recipe copies `bin/` into the same store path as `share/` (bash-completion's realpath
  lookup; nix-darwin profiles link only `/share/zsh`) — `symlinkJoin` only for devShell-only use, with the
  reason stated.
- **N6 S2** `installShellFiles` hook rather than hand `install -Dm644` (or a comment why not).
- **N7 S2** `checks.<system>.cmd-completions` lints the files and diffs literal lists against the script;
  `nix flake check` passes.
- **N8 S3** `nixfmt` clean; comment why the wrapper exists (`writeShellApplication` emits only `bin/`).
- **N9 S3** fish absent by decision, one line in the PR.

## Docs / PR

- **D1 S1** Help-vs-code drift and validation gaps listed (`grammar.md` rows with `drift/gap`).
- **D2 S1** Verification block pasted verbatim from `scripts/verify.sh`: `static`, `zsh`, bash on PATH,
  `/bin/bash`, `controls`, all `FAIL 0`. No block ⇒ the PR claims untested code.
- **D3 S2** "Using it" for bash (nothing with bash-completion ≥ 2; `source` fallback) and zsh (loader or
  one-liner) — `assets/pr-description.md`.
- **D4 S2** Grammar table with the SHA in the PR; comments in code cite `file:line` at every gate and
  exclusion.
- **D5 S3** Descriptions consistent with the usage text; commit = emoji + imperative; no generated
  files (`result`, `.zcompdump`) committed.
