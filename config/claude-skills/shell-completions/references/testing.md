# Verifying completions — `cases.tsv`, the harnesses, and what bites

Completion code cannot be unit-tested from a script: `_arguments` refuses to run outside a
completion widget and `compopt` outside a completion. Everything below drives real shells in a
pty. **pty allocation is denied in the sandbox — run `scripts/verify.sh` unsandboxed.**

## `cases.tsv`

`id	shell	line	assert	expect	bash32	notes` (tab-separated; `#` lines and the header are skipped;
`{sp}` stands for a literal space because TSV cannot carry trailing spaces; the cursor is always at
the end of `line`).

| column | values |
|---|---|
| `shell` | `zsh` · `bash` · `both` |
| `assert` | `set_eq` exactly these candidates (`a\|b\|c`, `-` = none) · `set_empty` · `set_has` · `set_not` · `buf` the whole line after `<TAB>`, exact · `buf_unchanged` · `msg` / `msg_not` zsh-only, substring of a `_message`/description text |
| `bash32` | `same` · `skip` · `expect:<alternative>` — applied when the bash under test is 3.x |

Set comparisons strip a trailing space and a trailing `/` from candidates (the bash 3.2 branch adds
both itself; zsh reports `dir` for `dir/`). Candidates come back **unquoted** (`file with space.yaml`);
`buf` sees the quoting the shell inserted (`file\ with\ space.yaml`).

Mandatory rows per grammar row (see `grammar.md`): positive (`set_eq`), a prefix that narrows,
`set_empty` at every position before the first legal flag word, `set_eq` without the ignored flag in
the branch that ignores it (+ a positive control where it is consumed), `buf` ending in `--opt=` for
same-word values, zsh `msg_not` for the next-word form, already-present flag filtered, directory `buf`
ending in `/` and an escaped-space file name, `set_empty` past the last argument of every subcommand
(zsh `msg` "no more arguments"), `buf` for a unique prefix (space appended) and `buf_unchanged` for an
ambiguous one. `scripts/verify.sh` adds two controls: a deliberately wrong expectation must FAIL in
each harness.

## Running

Both harnesses run cases in parallel (`COMPLETION_JOBS`, default 6) and `verify.sh` runs the three
shells concurrently — a full run takes about 5 s. Output order is stable. `verify.sh` first checks,
in about a second, that a pty can be opened, that a bash ≥ 4 with readline exists
(`BASH_INTERACTIVE` overrides the search) and that `uv` can provide pexpect; `PREFLIGHT FAIL`
names the fix. Each harness then runs under a watchdog (`VERIFY_TIMEOUT`, default 120 s). If a busy
machine makes a `buf` row flaky, rerun with `COMPLETION_JOBS=1` before suspecting the completion.

```
scripts/check-static.sh _cmd cmd.bash
scripts/verify.sh cmd _cmd cmd.bash cases.tsv [--cwd fixture-dir]     # everything + evidence block
zsh scripts/test-zsh-completion.zsh <dir-containing-_cmd> cases.tsv [--cwd DIR]
uv run scripts/test-bash-completion.py cmd.bash /bin/bash cases.tsv [--cwd DIR]
/bin/bash --noprofile --norc scripts/bash-list.sh cmd.bash cmd 'cmd sub '   # one-off candidate list
```
Output contract: `PASS|FAIL <id>  <notes>` per row (a FAIL line is followed by typed/assert/expect/got),
then `<harness> <version>  PASS n FAIL m`; exit 1 on any FAIL. `verify.sh` ends with the `## evidence`
block to paste into the PR. `--cwd` matters for file rows: keep a fixture dir with `dir/`,
`file with space.yaml`, `plain`, `x:y.txt`.

## How the harnesses work (so you can extend them)

**zsh** (`test-zsh-completion.zsh` + `harness.zshrc`): one fresh `zsh -f -i` per row under `zpty`,
`env -i` with `COMPLETION_DIR` and `CAP_FILE`. The rc puts the dir first on `fpath`, runs
`compinit -D -u` (no dump, no security prompt), sets `format` zstyles (`MSG:%d`, `DESC:%d`, `WARN:%d`
— without a format style `_message` output is invisible), `LISTMAX=100000`, and binds `^I` to a
widget that runs `zle expand-or-complete` and appends `LIST:`, `MSG:`, `BUF:<…>`, `END` to `CAP_FILE`.
Matches are captured by shadowing `compadd`: `builtin compadd -O t "$@"` records what would be added,
then `builtin compadd "$@"` adds it. Calls that already carry `-O`/`-A`/`-D` are pass-through
(`_describe` pre-filters with its own `-O`; intercepting it empties its array). A `-S` suffix other
than space or `/` is appended to the recorded match (`--tag` + `=`); `_message` is wrapped to record
its text (`_arguments`' "no more arguments" does not go through `compadd -x`). Recorded matches are
`(Q)`-unquoted.

**bash** (`test-bash-completion.py`): set rows run `bash-list.sh` under the target bash — it sources
the file, rebuilds `COMP_WORDS` the way that bash version splits (≥ 4 at `=`/`:` too), sets
`COMP_LINE/POINT/CWORD` and `$2`/`$3`, calls the function registered by `complete -p`, prints
`COMPREPLY`. `buf` rows spawn `bash --noprofile --norc -i` with pexpect (`dimensions=(40,200)`,
`TERM=dumb`, `INPUTRC=scripts/inputrc`), send the line + `\t` and, without waiting (readline
handles keys in order, so the completion finishes before C-a runs), read the buffer back with
C-a `echo 'BU''F:<` C-e `>'` Enter — the marker is split so the echoed command can never match.
Fresh session per row, `HISTFILE=/dev/null`, and a no-op shell function named like the command, so
a stray Enter can never run the real CLI. A bash without readline is refused up front.

## Things that bit us (all baked into the harnesses)

- Typing before zle has drawn its prompt: the terminal re-init flushes pending input, so half a
  line arrives. Wait for `ESC[?2004h` (bracketed-paste-on, emitted when zle starts reading) after
  spawning **and** after every command you send.
- `zpty` output reads are chunked: accumulate until the marker appears; split markers (`RE''ADY`,
  `BU''F:<`) so the echoed command text never matches.
- `${(uj:|:)arr}` does not deduplicate — zsh joins (rule 10) before unique (rule 18); use
  `${(j:|:)${(@u)arr}}`. `"${(f)…}"` without `(@)` collapses to one word.
- readline is silent under zsh's `zpty` even with `stty rows/cols`; pexpect (`forkpty`) works.
- zsh `((n++))` returns 1 when `n` was 0 — breaks `ok || bad` and `set -e`; use `n=$((n+1))`.
- `source file | head` runs `source` in a subshell (functions vanish).
- pty input lines longer than ~1 KB get mangled: `source` a file instead of typing it.
- Pager prompts ("do you wish to see all N possibilities?") swallow the next keystrokes:
  `LISTMAX=100000` (zsh), `completion-query-items 100000` + `page-completions off` (bash).
- Disable autosuggestion/highlighting plugins in test shells (`zsh -f`, `--norc`) — they paint text
  into the capture.
- `nix develop -c bash …` runs stdenv's minimal non-interactive bash, which has no `progcomp`
  (`shopt: progcomp: invalid shell option name`); a plain interactive `nix develop` starts
  bashInteractive, which does. Test with the interactive bash on PATH and `/bin/bash`, never with
  `nix develop -c bash`.
- File names with `:`, `=` or `@`: bash ≥ 4 splits `COMP_WORDS` there and readline replaces only
  the text after the last break character (`$2`). Completion code that indexes `COMP_WORDS` puts
  flags inside such names; rebuild the shell words from `COMP_LINE` (template `_CMD__split`) and
  keep a `buf` row with an `x:y` fixture. `bash-list.sh` emulates the `=` and `:` split but not
  readline's `@` quirk — `buf` rows (real readline) are authoritative there.
- A `set -e` in a harness turns a failing assertion into an aborted run: count failures instead.
- `${#${(M)${(v)jobstates}:#running*}}` counts the *characters* of the joined string, not jobs:
  assign to an array first. (This silently serialised the parallel zsh harness.)
- An interactive `bash -i` with the real `HOME` appends to `~/.bash_history` and trims it:
  `HISTFILE=/dev/null`. zsh `-f` under `env -i` has no `HISTFILE`.
- Each test zsh runs `compinit`; keeping only zsh's own function dirs plus the one under test on
  `fpath` halves the per-case start-up.
