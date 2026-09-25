---
name: shell-completions
description: Write, fix, review or package shell tab completions — zsh compsys `_cmd` files and bash `complete -F` scripts — for a CLI or in-repo script, including the Nix side (writeShellApplication, installShellCompletion, symlinkJoin, XDG_DATA_DIRS, fpath, compinit, home-manager) and pty-based verification on zsh, bash 5 and macOS /bin/bash 3.2. Use it whenever the user mentions completions, tab completion, compdef, compinit, fpath, bash-completion, COMPREPLY, a `_foo` file, "make TAB work" for a script, adding a subcommand or flag to a script that ships completions, or reviewing a completions PR — the result must pass a strict review (Copilot, Claude) with zero findings, so use the skill even for a "small" completion.
---

# shell-completions

Hand-written completions look trivial and are reviewed hard. Three practices make them pass:

- **Read the grammar from the dispatcher, not `--help`.** Usage text drifts: it lists flags a
  branch ignores and marks required arguments optional. The completion must offer what the code
  accepts, at the word where the code reads it.
- **Apply the shell rules that are easy to miss.** `_arguments` optspecs are position-independent;
  bash 3.2 does not split `COMP_WORDS` at `=`; a global `complete -o filenames` rewrites
  look-alike candidates; `symlinkJoin` drops `meta`. The templates encode all of these.
- **Verify in a pty on zsh, bash 5 and `/bin/bash` 3.2 before saying "done".** Completion code
  only runs inside a completion widget, so reading it is not testing it.

Deliverable: `_cmd` + `cmd.bash` + packaging + a `cases.tsv` + the verify evidence block in the PR.

## Workflow

### 0. Generated or hand-written?

If the tool can emit its own completions (cobra `completion`, clap, click/typer, argparse+shtab),
ship those with `installShellCompletion --cmd x --bash <($out/bin/x completion bash) --zsh <(…)`
(`assets/package.nix.md`) and jump to step 5. Otherwise hand-write.

### 1. Extract the grammar from the code — never from `--help`

Read the dispatcher `case` and every handler; fill the table in `references/grammar.md` (position,
kind, allowed values, *where each value is validated and consumed*, which flags are parsed from
which word — `"${@:4}"` means "from `$4`" — in which form (`--x=v` same-word only vs `--x v`), which
flags a handler silently ignores, exact arity checks, stubs). Pin the script's git SHA in the header.

Then **stop and report** to the user before writing anything: every `help ≠ code` row (a flag help
lists but a branch ignores; `[ro|rw]` in help while the code requires it; extra words silently
accepted), every unvalidated value, every stub. The completion follows the code; the user decides
about the help text or the code. Never edit the CLI to make the completion simpler. If nobody can
answer (a subagent or non-interactive run), carry on following the code and put the drift list at
the top of your report and in the PR.

### 2. zsh — start from `assets/_CMD`

Keep the shape: `#compdef cmd`; the manual's full local list (`curcontext="$curcontext" context
state state_descr line ret=1; typeset -A opt_args`); `': :->cmd' '*:: :->args'` so `$words[N]` is
the CLI's `$N`; `_describe` for commands; per subcommand a `specs` array and **one**
`_arguments "${specs[@]}" && ret=0`, which says "no more arguments" past the last spec — but with
an *empty* spec list it says nothing, so an arm that takes no arguments calls
`_message 'no more arguments'` itself (the template does both; `_values` for positionals would
return silently); values with descriptions `((v\:"desc"))`; options **always** as optspecs,
never words in a positional list (that adds a trailing space and no exclusion); `--opt=-` when the
value is accepted only in the same word; optspecs appended only when `CURRENT` has reached the word
the CLI parses flags from, and not in a branch that ignores them; `return ret`; the guarded
dual-mode footer. Details and the reasons: `references/zsh.md`.

### 3. bash — start from `assets/CMD.bash`

`# shellcheck shell=bash` first line; `cur=$2` (never `${COMP_WORDS[COMP_CWORD]}`); rebuild the
shell-level words with the template's `_CMD__split` — bash ≥ 4 splits `COMP_WORDS` at `=`, `:` and
`@` (so `--tag=x` or a file name `a:b` becomes several words) while 3.2 does not, and indexing
`COMP_WORDS` directly puts flags inside file names; offer candidates for the whole word and strip
the prefix readline will not replace (`pre`); candidates
via a literal `for w in …` loop (no `compgen -W "$var"`, no `mapfile`, no `$(compgen)` in an array
assignment); `compopt -o filenames` only in the file branch, `compopt -o nospace` only when the
unique candidate ends in `=`, both guarded by `type compopt`; no global `-o` on `complete` except
`-o nospace` in the 3.2 branch, where the function appends spaces itself and quotes file names
with `printf %q` (readline only quotes under `-o filenames`). Must `source` and work on
`/bin/bash` 3.2 — that is the documented fallback for people without bash-completion.
Details: `references/bash.md`.

### 4. Package

`assets/package.nix.md`. Default: `runCommand` that copies `bin/<cmd>` and runs
`installShellCompletion --cmd cmd --bash … --zsh …`, with `meta = app.meta`. Names are fixed:
`share/zsh/site-functions/_cmd`, `share/bash-completion/completions/cmd.bash`. `git add` the new
files — a flake cannot see untracked files. Add a `checks.<system>` derivation that lints the files
and diffs the literal lists against the script's arrays. How shells find the files (devShell →
`XDG_DATA_DIRS` → bash-completion on first TAB; zsh needs a loader; `home.packages` → fpath +
compdump): `references/nix.md`.

### 5. Verify — in a pty, on three shells, before saying "done"

Write `cases.tsv` from the grammar table (`assets/cases.example.tsv`; the mandatory rows per grammar
row are in `references/testing.md`), then run **unsandboxed** (pty):

```
scripts/verify.sh cmd _cmd cmd.bash cases.tsv [--cwd fixture-dir]
```

It runs `check-static.sh`, the zsh harness (real compsys in a pty, captured matches/messages/buffer),
the bash harness under the bash on PATH and under `/bin/bash` 3.2, and two controls that prove the
assertions bite, then prints the evidence block:

```
static  PASS n FAIL 0
zsh 5.9.2  PASS n FAIL 0
bash 5.3.15(1)-release  PASS n FAIL 0
bash 3.2.57(1)-release  PASS n FAIL 0
controls  PASS 2 FAIL 0
```

Paste that block verbatim into the PR. If you could not run it (no pty, no `/bin/bash`), say so in
the PR instead of implying it ran. Then `nix build`/`nix develop` the package, `ls` its `share/`,
and `nix flake check`.

### 6. Self-review and PR

Walk `references/review-checklist.md` (every item has a detection method — most are already
covered by `check-static.sh` and your cases). PR body from `assets/pr-description.md`: what, "Using
it" for bash and zsh, the grammar table with the SHA, the drift list, the evidence block, fish not
shipped. Repo rules apply (dotfiles: `nix develop -c ci`, `build`, never `switch`; commits are
emoji + imperative).

## Reviewing someone else's completion PR

Same order: extract the grammar table from the CLI first, then read the completion against it,
then run `check-static.sh` and — if the fixture layout allows — the harnesses. Report with
`file:line`, the fix, and blocker/nit. The checklist's ★ items are the ones reviewers flag most
often. Check every fix you propose against the same rules — a fix that uses `mapfile` or an
unguarded `compopt` reintroduces a bash 3.2 defect.

## Files

- `references/grammar.md` — the table, the 15 mapping rules, a filled example
- `references/zsh.md`, `references/bash.md`, `references/nix.md` — the shell and packaging facts,
  each with the source it comes from and what was verified in a pty
- `references/review-checklist.md` — G/Z/B/N/D items with severity and detection
- `references/testing.md` — `cases.tsv` schema, harness internals, the traps
- `scripts/` — `check-static.sh`, `test-zsh-completion.zsh` (+ `harness.zshrc`),
  `test-bash-completion.py` (+ `inputrc`, `bash-list.sh`), `verify.sh`
- `assets/` — `_CMD`, `CMD.bash`, `package.nix.md`, `cases.example.tsv`, `pr-description.md`
- `evals/` — the synthetic `ferry` CLI with a verified reference solution and cases; a deliberately
  flawed pair for review practice
