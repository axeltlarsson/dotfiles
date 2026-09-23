# tmux-links

Find, preview and open every link in a tmux pane — OSC 8 hyperlinks (whose
target is hidden behind a label), bare URLs, and file paths — from the
keyboard, without leaving tmux.

| Key | What |
|---|---|
| `prefix O` | fzf picker: links in view in reading order, then history newest first |
| `prefix L` | in-buffer jump: every link in view highlighted, `n`/`N` cycle |
| copy-mode `o` / `O` | open the selection, or the link under the cursor |
| copy-mode `p` | preview the link under the cursor in a popup; Enter opens |
| picker `Ctrl-Y` | copy the target · `Ctrl-/` toggle preview |

Opening dispatches on kind: URLs to the browser, files and directories to
`$EDITOR` in a new tmux window, images, PDFs and other binaries to `open`.

Options (tmux user options): `@links-history` lines of scrollback to scan
(2000); `@links-ignore` an ERE dropping matching targets (the Claude Code
session link by default).

## How it ties together

Everything is a pipeline of tab-separated records over small awk stages;
`main.sh` is glue and the three front-ends.

```
capture-pane -e -J ─▶ extract.awk ─▶ classify.awk ─▶ order.awk ─▶ render.awk ─▶ fzf
   (visible, then      OSC 8, bare     one batched     dedupe,      icons, dim
    -S -2000 history)  URLs, paths     stat -L         grouping     targets
                            │
                            └─▶ jump: labels → ERE alternation → copy-mode search-backward
                            └─▶ open-at / preview-at: the one line under the cursor
```

**extract.awk** works on `capture-pane -e -J`: `-e` keeps the escape
sequences so OSC 8 hyperlinks can be split into target and label, `-J`
re-joins lines wrapped at the pane edge so a long link is one record. OSC 8
is `ESC ] 8 ; params ; URI ST label ESC ] 8 ; ; ST` — the `params` (usually
an `id=`) is why it splits on `]8;` and takes everything after the first `;`.
Labels are blanked out of the text before the bare scans, so a label that
looks like a path is not found twice. Bare URLs are found by scanning to a
delimiter and *then* trimming trailing punctuation, with `)` only trimmed
when unbalanced — one regex describing a whole URL is how copycat glues
`https://a, https://b` together and eats a trailing `)`. Bare paths must
start with `/`, `~/`, `./` or `../`, and outside the single-line
cursor lookups must sit under `$HOME` or the pane's cwd, which kills most
false positives from prose. Records carry byte offsets so the cursor lookups
can find "the link at column x".

**classify.awk** is the only stage that touches the disk: the candidates go
to a temp file and through one `xargs -0 stat -L`, so a scan with hundreds
of candidate paths costs one `stat` batch, not hundreds of forks. (A gawk
coprocess was tried first: with zero candidates it never opens and the read
side hangs, and a large batch deadlocks on the pipe.) Paths that do not
exist are dropped here; fifos, sockets and devices become `binary` so
nothing ever tries to read them. Otherwise kind is `file`, `dir`, `image`
or `binary` by extension — `image` meaning "sips can rasterise it", which
includes PDFs.

**order.awk** dedupes on target: the visible region keeps reading order
(first occurrence wins), history runs newest first (last occurrence wins),
a target in both appears once in the visible group, and the longest label
seen wins because a wrapped link can contribute fragments. It sorts with
`PROCINFO["sorted_in"]`, so no external `sort`.

**render.awk** produces `<icon>  <label>  <dim target>\t<target>\t<kind>\t<prio>`;
fzf shows field 1, hands back fields 2–3, and field 4 orders the list once a
query is typed (below). Icons come from `icons.tsv`
(`host:`, `ext:`, `kind:` keys) — nerd-font glyphs only, from the same
`nvim-web-devicons` table as the editor. Column alignment is computed under
`LC_ALL=C` as bytes minus UTF-8 continuation bytes, i.e. one cell per
character, which is how tmux lays them out; supplementary-plane icons and
emoji are avoided because tmux sizes them at one cell while the terminal
draws two.

**The picker** is `fzf --tmux`, fzf's own popup integration. It resolves the
pane itself, which matters: `display-popup` does not expand formats in its
arguments, so a `#{pane_id}` passed straight to it arrives literally.
fzf has no per-item weights, but for equal match scores it falls back to
input order (`--tiebreak=index`, not `--no-sort`), so input order *is* the
weight: rows are fed in reading order while the query is empty, and a
`change` binding reloads them sorted by `render.awk`'s priority field as
soon as you type — a labelled link over a bare one, a file over a bare URL,
directories last. (fzf's default `length` tiebreak does the opposite:
it prefers the shorter row, i.e. the directory over the file in it.) The
preview window sits right at ≥ 70 columns and drops below otherwise, so it
follows fullscreen vs split.

**The jump** is copycat's idea done without copycat's failure modes: the
on-screen text of every link in view (label if it has one, else the target)
is regex-escaped, joined longest-first into one alternation, and handed to
`copy-mode` + `search-backward`. tmux highlights all matches and `n`/`N`
cycle natively, so there is no plugin state, no temp files, no column
arithmetic. The regex only has to *land the cursor* on the link: what gets
opened is `#{copy_cursor_hyperlink}`, the grid's own hyperlink attribute,
falling back to a scan of `#{copy_cursor_line}` at `#{copy_cursor_x}` for
bare links (converting the cell column to a byte offset first), and finally
to text equal to the label of a link in view — the search highlights any
occurrence of a label, so plain prose that repeats one opens the same
target. A
hyperlink wrapped across the pane edge only matches its first fragment, but
the cursor still lands inside it and the grid attribute resolves the whole
target. A *bare* URL or path wrapped across rows is a known gap: the
cursor lookup scans one rendered row, so it sees only the fragment on that
row. The alternation is capped at 12 KB, under tmux's 16 KB command limit.

**Opening** normalises the text by running it through the extractor as a
synthetic OSC 8 link, so `file://host/…` authorities and `%XX` escapes are
decoded in exactly one place. URLs are percent-encoded to RFC 3986's set
before `open`, which otherwise launches an empty browser on a stray `^` or
`å`.

## Previews

Files → `bat --paging=never` (with a real tty, bat would otherwise page and
eat the first keypress). Directories → `eza`, falling back to `ls`. URLs →
a structural breakdown (host, path, one line per query parameter, fragment)
and, for GitHub PRs and issues, `gh pr/issue view` inline. **Nothing ever
fetches an arbitrary URL:** a scrollback routinely contains one-time links
(1Password shares, magic logins) and tracking links, and arrowing past one
in fzf must not consume it. `gh` is the exception because it is an
authenticated API client, not a fetch of the link.

### Images and PDFs

This is the only genuinely intricate part, and every piece of it exists
because of a specific constraint that was measured, not assumed.

Ghostty speaks the kitty graphics protocol, and the preview uses its
*Unicode placeholder* mode: the image area is a grid of `U+10EEEE` cells,
each tagged with a row and a column combining character from kitty's
diacritics table (`diacritics.txt`, 296 entries), with the foreground
colour carrying the image id. The terminal binds those cells to whatever
image it holds under that id. Placeholders are ordinary text, so tmux and
fzf lay them out, scroll them and clip them like any other cells — that is
what makes images survive a multiplexer at all.

The pixels take a different route, for three reasons found the hard way:

1. **tmux drops passthrough during a popup redraw.** `popup_set_client_cb`
   returns 0 while `CLIENT_REDRAWOVERLAY` is set, and fzf repainting the
   preview sets it in the same write that would carry the image. Routing the
   data through fzf's preview output therefore never works in a popup (it
   works fine in a plain pane, which is what made it confusing).
2. **Two writers to one pty corrupt each other.** Writing the data into the
   popup's tty from a background process, after fzf had gone idle, worked
   most of the time — until a fast back-and-forth interleaved fzf's bytes
   into the middle of a 1 MB DCS stream. tmux fell out of the passthrough,
   the rest rendered as base64 text, and a killed half-written sequence left
   the parser inside an unterminated DCS: the whole terminal had to be
   reset.
3. **chafa probes the terminal**, and a popup's input parser (no pane behind
   it) never answers, so it waited out a multi-second timeout on every hover.

So: the placeholder grid is generated by `kitty.awk` (no chafa) and printed
immediately, which is what fzf needs to replace the previous preview; then
a detached subshell resamples the source with macOS `sips` to twice the
cell area in points (Ghostty reports cell sizes in points; ×2 assumes a
retina display), caches the PNG in `~/.cache/tmux-links/` keyed by path,
mtime, size and target pixels (atomic rename, 30-day expiry), and hands the
terminal **the file path** via kitty's `t=f` medium. That sequence is ~110
bytes: one write, atomic on a tty, nothing to interleave, no chunk stream to
cut in half. It is sent twice (0.1 s and 0.5 s after the resample, by which
time the preview has exited) in case the first still lands on a pending
redraw; re-transmitting an id is harmless. Ghostty scales the source on the
GPU, so the result is sharp rather than chafa's bitmap at tmux's logical
cell size.

`sips` reads PDFs natively (first page, 0.08 s), so a PDF is just an image
here. Pages have no background, so their placeholder cells get a white
background — the image is drawn over the cell background, which is a
one-SGR fix for "unreadable in dark mode". `qlmanage -t` (Quick Look) was
evaluated as an alternative rasteriser: it also handles docx/pptx, but it
is twice as slow and produces the same transparent output, so it was not
adopted.

Why not chafa at all? It rasterises to block art or to a pixel protocol,
and once placeholders are generated locally and pixels go by path its only
remaining job was the non-kitty fallback. This targets Ghostty, so it went;
on a Linux host an image row just shows the `file -b` line.

## Performance

Measured on a pane with 1,870 history lines / 400 KB (a Claude Code
session), M-series MacBook:

| Stage | ms |
|---|---|
| `capture-pane -J -S -2000` | 41 |
| `extract.awk` | 90 |
| `classify.awk` (one `stat` over 24 candidates) | 86 |
| `order.awk` | 24 |
| `render.awk` | 23 |
| **picker data, end to end** | **~200** |
| image hover → cells visible | ~50 |
| image hover → pixels, cold / cached | ~350 / ~150 |
| each `tmux display-message` round-trip | ~12 |

What's left on the table, honestly:

- **Process startups dominate.** Each gawk start is ~15–20 ms; the pipeline
  has five, plus `sh`/`xargs`/`stat`, plus six or seven tmux round-trips
  (`@links-ignore` is read once per `extract`, so twice in `pick`). Merging
  the four awk stages into one program would save ~50 ms; folding the tmux
  queries into a single `display-message` with several formats saves ~40 ms.
  Both are mechanical. That is the realistic floor for this design: ~100 ms.
- **`capture-pane` is 40 ms and not ours** — it is tmux serialising 2000
  lines with attributes. The history cap is the lever; 2000 lines is already
  a compromise between reach and latency.
- **`sips` is 170 ms on a large image** and runs once per image per size,
  then hits the cache. It is not on the path to the first paint.
- The `jump` builds one search regex from every label in view, longest
  first, and stops adding at 12 KB: tmux rejects a command over ~16 KB. On a
  screen dense with long URLs the shortest ones are left out of the
  highlight.
- The cursor lookup (`o`/`p` in copy-mode) scans one rendered row, so a
  bare link wrapped across rows resolves to the fragment on the cursor's
  row. Hyperlinks are unaffected.

### Would Zig or Go make sense?

Rewriting would buy: one process instead of ~10 (recovering most of the
~100 ms above), a real test suite for the escape-sequence parser (the part
that actually produced regressions during development: the `id=` param,
wrapped labels, the placeholder codepoint constant), and correct
display-width handling instead of the byte-counting approximation.

It would not buy: any speedup of `capture-pane`, `sips`, `stat`, `gh` or
fzf, which together are most of the wall clock; anything about the popup
passthrough constraints, which are tmux's; or simpler deployment — the
shell version is already a single Nix derivation with no build step, and
editing the icon table or a regex is a text edit, not a compile.

Verdict: **good enough, and the right shape for a personal tool.** The
remaining 200 ms is imperceptible inside fzf's own startup. The one thing a
rewrite would genuinely improve is testability of the extractor — and that
is better addressed by a `test.sh` with the known-nasty inputs than by a
language change. If this ever becomes a distributed plugin (tpm users
without Nix), the calculus flips: a single static binary with tests is the
right vehicle then, and Lorentz's Zig `tmux-claude-links` is the reference
for that path.

## Dependencies

`tmux ≥ 3.4` (hyperlinks, `copy_cursor_hyperlink`, popups with passthrough),
`fzf ≥ 0.53` (`--tmux`), `gawk`, GNU `coreutils` and `findutils`, `bat`,
`file`. Optional: `eza`, `gh`. Images additionally need Ghostty (or another
kitty-graphics terminal that supports Unicode placeholders and the file
medium), `allow-passthrough on` in tmux, and macOS `sips`.

The tmux side: `set -as terminal-features ",xterm-ghostty:hyperlinks"` so
tmux forwards OSC 8 to Ghostty at all (its terminfo has no `Hls`), and
`set -g allow-passthrough on`.
