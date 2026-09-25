# The grammar table — read the code, not the help

The completion must offer what the code accepts, at the word where the code reads it — and usage
text is the least reliable source for that. Fill this table from the dispatcher and its handlers
**before** writing a line of completion; the table is also the spec for `cases.tsv` and goes into
the PR.

Header: `CLI: <path> @ <git sha>` (`git log -1 --format=%h -- <path>`; outside a repo
`git hash-object <path>`). Re-extract before merge if the script changed.

| column | meaning |
|---|---|
| `subcmd` | dispatcher word, or `—` for the top level |
| `pos` | CLI `$N`; `$N+` for a repeated tail |
| `kind` | `cmd` · `pos` · `opt-pos` · `flag` · `flag=val` · `file` · `dir` · `free` · `terminal` |
| `values` | literal set (quote the array/case arm), `_files`, or `free text` |
| `validated` | `file:line` of the check that rejects other values, or `none` |
| `consumed` | `file:line` where the value changes behaviour, or `ignored (branch)` |
| `depends` | condition on an earlier word (`$1 == ship`), or `—` |
| `form` | `word` · `same-word =` · `next-word` · `both` · `exact-literal` |
| `arity` | `exact N` (`$# -ne N`) · `N..M` · `≥ N` · `repeat-idempotent` · `repeat-effective` |
| `help says` | usage text for the slot, verbatim |
| `drift/gap` | `help ≠ code` · `unvalidated` · `unused` · `stub` · `—` |
| `offer?` | `Y` / `N` / `Y (stub desc)` + one-line rationale |
| `zsh` / `bash` / `cases` | the spec fragment, the case arm, the case ids that prove them |

## Mapping rules

Index rule: CLI `$N` ⇔ bash `COMP_CWORD == N` (`COMP_WORDS[0]` is the command) ⇔ zsh
`CURRENT == N` inside the `*::` state (`$words[1]` is the subcommand) ⇔ nested `_arguments`
positional `N-1`.

1. **Flags parsed from `"${@:N}"`** ⇒ zsh optspecs appended only when `(( CURRENT > N-1 ))`; bash
   flag arm only for `COMP_CWORD >= N`. Optspecs are position-independent by default.
2. **Value accepted only in the same word** (`--opt=*)` arm, `*)` rejects `--opt v`) ⇒ zsh
   `--opt=-[desc]:msg:` (empty action = message for free text); bash candidate `--opt=` + `nospace`.
3. **Both forms accepted** ⇒ zsh `--opt=[desc]:msg:action`; bash offer `--opt` and complete the
   value at the next word.
4. **Handler ignores the flag in a branch** (`fetch` parses `--tag` but never reads it) ⇒ don't
   offer it there; list it under drift.
5. **Required but unused positional** (counted by a `$#` check, never read) ⇒ still offer; list the
   gap.
6. **Exact / maximum arity** ⇒ nothing past the last position: zsh `_arguments` with exactly the
   described positionals ("no more arguments"); bash no arm ⇒ empty `COMPREPLY`, and no
   `-o default`/`bashdefault` anywhere.
7. **Optional positional** ⇒ zsh `'k::msg:action'`; bash offer at that index only.
8. **`-`-literal accepted only at a fixed `$N`** (`[ "${2:-}" = --json ]`) ⇒ a positional with a
   description, not an optspec.
9. **Repeatable flags**: idempotent ⇒ plain optspec (zsh excludes it once present; bash filters by
   `${w%%=*}`); effective repeats ⇒ `'*--opt…'`, no filter.
10. **Files**: `[ -f ]` ⇒ `_files` / `compgen -f` + `compopt -o filenames`; `[ -d ]` ⇒ `_files -/` /
    `compgen -d`; an extension filter only if the CLI checks one.
11. **Free text** ⇒ zsh message only; bash returns nothing.
12. **Default arm**: offer a word only if the dispatcher names it (`${1-help}`); undocumented
    `-h/--help` fall-throughs are not completions. An empty default (`${1:-}` → print) offers nothing.
13. **Stubs**: exits 0 ("not yet implemented") ⇒ offer with "(not yet implemented)" in the
    description; rejected by `*)` ⇒ never offer.
14. **No dynamic lookups at completion time** (`aws`, `kubectl`, sourcing the script): snapshot the
    literal list; add a CI diff against the script's array so drift fails the build.
15. **Help ≠ code** ⇒ the completion follows the code; report every row with `drift/gap` set to the
    user before writing (they decide whether to fix help, code, or neither). Never edit the CLI to
    make the completion simpler.

## Example: `ferry` (evals/files/ferry/ferry)

| subcmd | pos | kind | values | validated | consumed | depends | form | arity | help says | drift/gap | offer? |
|---|---|---|---|---|---|---|---|---|---|---|---|
| — | $1 | cmd | ship fetch dock status help | `case "${1:-}"`; `*)` usage exit 2 | dispatcher | — | word | — | 4 usage lines | `-h/--help` undocumented fall-throughs | Y incl. `help`; N for `-h/--help` |
| ship/fetch | $2 | pos | eu us | `require_region` | yes | — | word | ≥ 3 | `(eu\|us)` | — | Y |
| ship | $3 | file | `_files` | `[ -f "$3" ]` | yes | — | word | ≥ 3 | `FILE` | — | Y |
| fetch | $3 | free | remote object name | none | yes | — | word | ≥ 3 | `FILE` ("download FILE from the region bucket") | unvalidated | message only: local files would be the wrong namespace |
| ship/fetch | $4+ | flag | `--force` | `parse_opts` `*)` exit 2 | yes | `CURRENT > 3` | word | repeat-idempotent | `[--force]` | — | Y from $4 |
| ship | $4+ | flag=val | `--tag=NAME` | `--tag=*)` only | ship yes; **fetch ignores** | `CURRENT > 3`, `$words[1] == ship` | same-word `=` | repeat (last wins) | listed for both | help ≠ code (fetch) | Y ship only, `=-` |
| dock | $2 | pos | north south east | `case` exit 2 | yes | — | word | exact 3 | ✓ | — | Y |
| dock | $3 | pos | ro rw | `case` exit 2 | yes | — | word | exact 3 | `[ro\|rw]` | help ≠ code (required) | Y, required |
| status | $2 | opt-pos | `--json` | `[ "${2:-}" = --json ]` | yes | — | exact-literal | ≤ 2 | `[--json]` | other `$2` silently ignored | Y |
| all | past last | terminal | — | `$#` checks | — | — | — | — | — | — | nothing / "no more arguments" |

Resulting specs: see `evals/grading/reference/ferry/_ferry` and `ferry.bash`; the cases that prove
each row: `evals/grading/ferry.cases.tsv`.
