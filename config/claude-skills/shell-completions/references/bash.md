# bash programmable completion — what you need to write `cmd.bash` correctly

Sources: `man bash` ("Programmable Completion", `complete`/`compgen`/`compopt`), bash NEWS/CHANGES,
bash-completion 2.18 (`bash_completion`: `_comp_load`, README, doc/styleguide.md, test suite).
[V] = verified locally on bash 5.3.15 and macOS `/bin/bash` 3.2.57. The template `assets/CMD.bash`
applies all of this.

## Calling convention

`complete -F _cmd cmd` — on `<TAB>` bash calls `_cmd cmd "$2" "$3"`: `$1` command, **`$2` the word
being completed**, `$3` the previous word. Fill `COMPREPLY`; bash filters nothing for you.
`COMP_WORDS`/`COMP_CWORD` are the line split at `COMP_WORDBREAKS` (default `" \t\n\"'@><=;|&(:"`),
`COMP_LINE`/`COMP_POINT` the raw line and cursor.

**Use `cur=$2`, not `${COMP_WORDS[COMP_CWORD]}`** [V]:

| typed (bash ≥ 4) | `COMP_WORDS` | `COMP_CWORD` | `$2` | `$3` |
|---|---|---|---|---|
| `tool --output=fo` | `tool --output = fo` | 3 | `fo` | `=` |
| `tool --output=` | `tool --output =` | 2 | `` | `--output` |
| `tool a:b` | `tool a : b` | 3 | `b` | `:` |

**bash 3.2 does not split `COMP_WORDS` at `=` or `:` at all** (bash 4.0 CHANGES: "The programmable
completion code now uses the same set of characters as readline when breaking the command line
into a list of words") — there `tool --output=fo` gives `COMP_WORDS=(tool --output=fo)`,
`COMP_CWORD=1`, `$2=fo`. So: take `cur` from `$2` (identical on both) and **rebuild the shell-level words** from
`COMP_WORDS` + `COMP_LINE` — glue the pieces back together unless whitespace separates them
(template `_CMD__split`). Then `words[N]` is the CLI's `$N` on every version, whatever `=`, `:` or
`@` the line contains. Readline still replaces only `$2`, so match candidates against the whole
word and strip the part before `$2`: `pre=${words[cword]%"$cur"}`, test `[[ $w == "$pre$cur"* ]]`,
add `${w#"$pre"}` [V: a file `x:y.txt` completes as `x:y.txt` on 5.3 and 3.2; indexing
`COMP_WORDS` directly inserted flags after `x:` on 5.3]. This generalises bash-completion's
`__ltrim_colon_completions` without depending on bash-completion.

## `complete -o` options, `compopt`

| option | effect | since |
|---|---|---|
| `filenames` | readline treats candidates as file names: `/` on directories, quoting, no space after a dir | 2.05 |
| `nospace` | no space after a completed word | 2.05b |
| `default` / `bashdefault` | readline / bash default completion **when `COMPREPLY` is empty** — i.e. files everywhere you offered nothing | 2.05 / 3.0 |
| `nosort` | keep order | 4.4 (3.2: "invalid option name", the whole `complete` fails) |

`compopt -o <opt>` (bash 4.0) changes the option **for the current completion only** — the way
to scope `filenames` and `nospace`. Outside a completion it errors; on 3.2 it does not exist:
`type compopt >/dev/null 2>&1` before using it, or `2>/dev/null`.

Why never globally [V]: `complete -o filenames` turns a candidate `db` into `db/` when a directory
`db` exists in cwd and inserts `key\=val`; `-o nospace` removes the space after every word;
`-o default` offers files after the last argument of an exact-arity subcommand. The bash-completion
style guide: "do not use `complete -o filenames` … use `compopt -o filenames` dynamically".

Idioms: `[[ ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == *= ]] && compopt -o nospace` (space after
`--opt=` only); `compopt -o filenames` inside the branch that ran `compgen -f`.

## Filling `COMPREPLY`

- `for w in a b c; do [[ $w == "$cur"* ]] && COMPREPLY+=("$w"); done` — literal, no expansion, no
  SC2207, works on 3.2.
- **`compgen -W "$var"` re-expands each word** — `$(…)`, `${…}` and backticks inside run [V]. Only
  ever pass literals; never tool output. `COMPREPLY=( $(compgen …) )` word-splits and globs (SC2207).
- Files: `while IFS= read -r f; do COMPREPLY+=("$f"); done < <(compgen -f -- "$cur")` plus
  `compopt -o filenames`; `compgen -d` for directories. Always `--` before `"$cur"`.
- Reset with `COMPREPLY=()` first; `local` every variable including loop variables; `${x-}` so the
  file survives `set -u` in whatever shell sources it; never print.
- Already-present flags are not filtered for you (zsh does that): compare `${w%%=*}` against the
  words already on the line.

## bash 3.2 (macOS `/bin/bash`) — the file must still `source` there

bash-completion 2.x needs bash ≥ 4.2, so 3.2 users have exactly one path: `source` the file. Parse
errors (`bash -n` catches): `[[ -v x ]]`, `;&`, `;;&`, `|&`, `case` with extglob without `shopt -s
extglob`. Runtime errors (`bash -n` does **not** catch): `mapfile`/`readarray`, `declare -A`,
`local -n`, `${x,,}`/`${x^^}`/`${x@Q}`, negative array indices `${a[-1]}`, `compopt`,
`complete -o nosort`, `"${a[@]}"` on an empty array under `set -u` (< 4.4). Fine on 3.2: `a+=(…)`,
`[[ =~ ]]`, `$'…'`, `<(…)`, `read -ra`, `printf -v`, `compgen -W/-f/-d`, `complete -o nospace/filenames`.

Parity technique (git's): register with `-o nospace` **only when `compopt` is missing**, and let
the function append the trailing space to every candidate that is not an `--opt=` and not a
directory (which gets `/`), and quote file names with `printf -v q '%q' "$f"` — readline only
quotes under `-o filenames`, so an unquoted `file with space.yaml` would be inserted as three
arguments. Then `--opt=` has no space, words do, directories chain, names are escaped — on both
versions [V].

## How bash-completion finds the file (2.18 `_comp_load`)

On the first `<TAB>` for an unknown command, in order: `$BASH_COMPLETION_USER_DIR` or
`$XDG_DATA_HOME/bash-completion` → its own `completions/` → for the command's **realpath** and for
every `$PATH` entry ending in `/bin`: `${dir%/*}/share/bash-completion/completions/` → each
`$XDG_DATA_DIRS` entry → fallback. File names tried: `<cmd>.bash`, then `<cmd>` (deprecated in
2.18); `_<cmd>` was dropped. So install **`<cmd>.bash`**. The sourced file must leave a compspec
(`complete -p cmd`) or the search continues. Gotcha: `<TAB>` before the file exists pins a minimal
compspec for the session → `complete -r cmd`. Loading bash-completion turns on `extglob`; a file
that must also work standalone cannot rely on it.

## Testing

- Non-interactive (`scripts/bash-list.sh`): set `COMP_LINE/COMP_POINT/COMP_WORDS/COMP_CWORD`, call
  `_cmd cmd "$2" "$3"`, print `COMPREPLY` — emulating both split styles. Cannot observe `compopt`
  effects.
- Interactive (`scripts/test-bash-completion.py`, pexpect): real pty with a window size, `--noprofile
  --norc -i`, an inputrc with `show-all-if-ambiguous on`, `bell-style none`, `completion-query-items
  100000`, `page-completions off`, `completion-display-width 0`, `enable-bracketed-paste off`; read the
  buffer back with C-a `echo 'BU''F:<` C-e `>'`. readline is silent under zsh's `zpty` — use pexpect.
- shellcheck: `# shellcheck shell=bash` on line 1 (no shebang in a sourced file); zsh files must not be
  shellchecked (SC1071).
