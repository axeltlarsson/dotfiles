# zsh completion (compsys) — what you need to write `_cmd` correctly

Sources: `man zshcompsys` (INITIALIZATION, UTILITY FUNCTIONS: `_arguments`, `_describe`,
`_values`, `_files`, `_message`), `man zshcompwid` (`compadd`), the `compinit` source,
`Etc/completion-style-guide` and zsh-users/zsh-completions' howto. [V] = verified locally
on zsh 5.9.2 in a pty. The template `assets/_CMD` applies all of this.

## File, header, registration

- `#compdef cmd` must be the first 8 bytes of line 1 (`#compdef -p pattern`, `-P`, `-k`, `-K` exist;
  `#autoload` marks helper files). "Files whose first line does not start with one of these tags
  are not considered to be part of the completion system."
- File name = function name: `share/zsh/site-functions/_cmd`. The first `_cmd` in `fpath` order wins.
- `compinit` reads the first line of every `_*` file on `fpath` **once, when it runs**, and registers
  `compdef -na _cmd cmd` (`-n`: don't override, `-a`: autoload). Adding a dir to `fpath` later does
  nothing until `compinit` runs again or you `autoload -Uz _cmd; compdef _cmd cmd` by hand.
- The dump (`.zcompdump`): plain `compinit` regenerates it when the number of `_*` files changes;
  a changed `#compdef` line or a renamed function needs the dump deleted by hand. `compinit -C`
  never validates it (the dotfiles delete it on every `switch`).
- Autoload semantics (`man zshmisc`): if the file contains only a function definition, the
  definition is executed and then the function is called; otherwise **the whole file is the
  function body** and runs once. A file that defines `_cmd() {…}` and *also* has other code
  therefore needs the trailing call — the cobra/clap footer:
  ```zsh
  if [[ $funcstack[1] == _cmd ]]; then _cmd "$@"; else (( $+functions[compdef] )) && compdef _cmd cmd; fi
  ```
  The `funcstack` check alone does not guard against `compdef` being undefined when the file is
  `source`d before `compinit`.
- Everything in one file; helpers named `_cmd_*` — function names are global, and a helper named
  like a core function (`_files`, `_values`, `_hosts`) shadows it for every completion.

## `_arguments` (the only tool you need for options and positionals)

`_arguments [-nswWCRS] [-A pat] [-O name] [-M spec] [:] spec…` — its own options must be
separate words (`-s -w`), and may be separated from the specs with a lone `:`.

| spec | meaning |
|---|---|
| `n:msg:action` | positional `n` (1-based, after the command word). `::` before msg = optional. |
| `*:msg:action` | all remaining positionals. `*::` **shifts `$words`/`CURRENT`** to the normal arguments — inside the state `$words[1]` is the subcommand, `$words[N]` is the CLI's `$N` [V]. `*:::` shifts to only the words covered by this spec. |
| `-o[desc]`, `--long[desc]` | flag; excluded once present unless the spec starts with `*` |
| `--opt=[desc]:msg:action` | value as `--opt=v` **or** `--opt v` |
| `--opt=-[desc]:msg:action` | value **only** as `--opt=v` (the CLI's `--opt=*` case arm) [V] |
| `--opt-[desc]:…` / `--opt+[desc]:…` | `-optv` / `-optv` or `-opt v` |
| `(-a --all)-a[desc]` | exclusion list; `(- : *)` = everything (used for `--help`) |
| actions | `(a b)` words · `((a\:"desc" b\:"desc"))` words with descriptions · `_files` · `->state` · `{code}` · a lone space = "argument required, nothing to offer" |

Own options that matter: `-C` (modify `curcontext` for `->state`, requires the local below), `-s`
(single-letter stacking `-vq`), `-S` (no options after `--`), `-A '-*'` (no options after the first
non-option argument), `-R` (return 300 for a state).

**The `->state` contract** (manual): "A function calling `_arguments` with at least one action
containing a `->string` must declare `local context state state_descr line` and `typeset -A opt_args`
… with `-C` also `local curcontext="$curcontext"`." Without them the values clobber the caller on
the completion stack (`_main_complete` has its own locals, but `_sudo` → `_normal` → your function
inherits whatever you leaked). The full line: `local curcontext="$curcontext" context state state_descr line ret=1; typeset -A opt_args`.

**Return value**: `_arguments` and every helper return 0 iff matches were added. The completer chain
(`_complete` → `_approximate`/`_ignored`) keys off it, so use `ret=1`, `… && ret=0`, `return ret`.

**Position gating** [V]: optspecs are position-independent — `_arguments '--force[…]' '1:region:…'`
offers `--force` while completing the region. When the CLI parses flags only from `$N`
(`parse_opts "${@:4}"`), build the spec array conditionally: `(( CURRENT > N-1 )) && specs+=(…)`.
When a subcommand parses but ignores a flag, do not add it in that branch.

**Past the last positional** `_arguments` shows "no more arguments" (a `_message`; visible only with
a `format` zstyle). Use `_arguments` for every arm — including ones with a single positional — so
all subcommands end the same way; `_values` for positionals returns silently. With an **empty**
spec list `_arguments` prints nothing at all, so an arm that takes no arguments calls
`_message 'no more arguments'` itself:
`if (( $#specs )); then _arguments "${specs[@]}" && ret=0; else _message 'no more arguments'; fi`.

**Options never as positional word lists**: `'3:option:(--force --tag=)'` gets a trailing space
after `--tag=`, no description and no exclusion [V]. The one exception is a literal that the CLI
accepts only at a fixed `$N` (`[ "${2:-}" = --json ]`): that *is* a positional —
`'1::option:((--json\:"machine-readable output"))'`.

**Options at an empty word**: `_arguments` offers optspecs for an empty word only when no
positional can go there; while a positional is still possible, options appear only once the user
types `-`. A flag that must show up at an empty word next to positionals is rule 8's positional
literal, not an optspec.

## Helpers

- `_describe -t tag 'group description' array` — `array=('name:desc' …)`; escape literal colons `\:`;
  extra `compadd` options may follow (e.g. `-S ''`). Use it for subcommands.
- `_values [-s sep] desc spec…` — for `a,b,c` / `k=v` lists *inside one word* (`-s ,`). Not for
  ordinary positionals.
- `_alternative 'tag:desc:action' …` — mix sources at one position (fixed words + `_files`).
- `_files [-/] [-g pattern] [-W dir]` — prefer over `_path_files`; `-/` for directories; add a `-g`
  filter only if the CLI filters extensions.
- `_message 'text'` / `_message -e tag 'text'` — free-text arguments; `_message -e` is what
  `_arguments` uses for "no more arguments".
- `compadd` directly only as `_wanted tag expl 'desc' compadd -- …` (style guide: a bare `compadd`
  without `"$expl[@]"` is an error). `-S ''` suppresses the space suffix; `-q -S =` adds an
  auto-removable `=`.

## Style (Etc/completion-style-guide — reviewers quote it)

- Descriptions: lowercase start, no trailing period, imperative mood; the same wording for the same
  thing; group descriptions singular, tags plural.
- `': :->state'` — the message of a `->state` spec is ignored, leave it a space.
- "Always use descriptions" — `((eu\:"EU bucket" us\:"US bucket"))`, never bare `(eu us)`.
- Per-subcommand context: `curcontext="${curcontext%:*:*}:cmd-$words[1]:"` first thing in the
  arguments state, so users can `zstyle ':completion:*:*:cmd-sub:*'`.
- No output from the completer (`_message`, never `print`); no `setopt`/`zstyle`/`compdef` in the
  body; `compinit` sets `extendedglob`, `nullglob`, `NO_shwordsplit` for you (arrays are 1-based).
- Don't complete `-h/--help` unless the dispatcher names them; offer the named default arm
  (`case "${1-help}"`) as a word.

## Pitfalls seen in review

1. Missing locals (above). 2. Options as positional word lists (trailing space). 3. `--opt=` where
the CLI only takes `--opt=v` (should be `=-`) [V]. 4. Ungated optspecs offered at positional slots
[V]. 5. `$words[N]` indices without the `*::` shift, or `$#words` (counts an empty trailing word
inconsistently). 6. `_values` for positionals (silent past the end). 7. A definition-plus-footer
file with no trailing call (nothing happens on the first TAB). 8. Helper files without `#autoload`,
helpers shadowing core functions. 9. Unescaped `:` in specs/descriptions, `%` in `-X` messages.
10. Calling external commands at completion time. 11. Testing outside zle: `_arguments:comparguments:
can only be called from completion function` — use a pty (`scripts/test-zsh-completion.zsh`).

## Where files are found

- `fpath` gets `$p/share/zsh/site-functions` for every `$NIX_PROFILES` entry (nix-darwin `/etc/zshenv`,
  home-manager `.zshrc`) — a `home.packages` tool is found on the first shell after `switch`.
- zsh never reads `XDG_DATA_DIRS`: devShell tools need a loader (`_xdg_lazy_complete` in the dotfiles,
  zsh-completion-sync) or `fpath+=(${commands[cmd]:h:h}/share/zsh/site-functions); autoload -Uz _cmd; compdef _cmd cmd`.
