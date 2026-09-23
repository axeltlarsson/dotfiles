# tmux-links: OSC 8 hyperlinks, bare URLs and file paths in a tmux pane
# Usage: tmux-links pick <pane>        fzf picker, links in view first then history
#        tmux-links jump <pane>        highlight the links in view, cycle with n/N
#        tmux-links open-at <pane>     open the link under the copy-mode cursor
#        tmux-links preview-at <pane>  preview it in a popup (Enter opens)
#        tmux-links list <pane>        print the picker rows
#        tmux-links open <target> [cwd]
#        tmux-links preview <target> <kind>
#        show <target> <kind> and open-piped [cwd] are the popup body and
#        the pipe-and-cancel target used by the above.
#
# Options: @links-history (lines of scrollback to scan, 2000)
#          @links-ignore  (ERE dropping matching targets, the CC session link)

LIB="${TMUX_LINKS_LIB:?}"
TAB=$'\t'

opt() {
  local v
  v=$(tmux show -gqv "$1")
  printf '%s' "${v:-$2}"
}

pane_fmt() {
  tmux display-message -p -t "$1" "$2"
}

# extract <group> <cwd> [ignore-ERE] [anywhere]; records are tab-separated
# "group seq row kind target label start end". Strings go via the
# environment: gawk -v mangles backslashes.
extract() {
  LINKS_CWD="$2" LINKS_HOME="$HOME" LINKS_ANYWHERE="${4:-}" \
    LINKS_IGNORE="${3-$(opt @links-ignore 'claude\.ai/code/session_')}" \
    LC_ALL=C gawk -f "$LIB/extract.awk" -v group="$1"
}

classify() { gawk -f "$LIB/classify.awk"; }
order() { gawk -f "$LIB/order.awk"; }
render() { LC_ALL=C gawk -f "$LIB/render.awk" -v icons="$LIB/icons.tsv"; }

# Ordered records for the region in view, plus history with "all". In
# copy-mode the view is scrolled back: capture-pane lines are relative to
# the live screen, so shift both ranges by #{scroll_position}.
records() {
  local pane=$1 cwd hist scroll height
  # scroll_position is empty outside copy-mode, hence the explicit separator
  IFS=$'\x1f' read -r cwd scroll height <<< "$(pane_fmt "$pane" $'#{pane_current_path}\x1f#{scroll_position}\x1f#{pane_height}')"
  scroll=${scroll:-0}
  hist=$(opt @links-history 2000)
  {
    tmux capture-pane -p -e -J -t "$pane" -S "-$scroll" -E "$((height - 1 - scroll))" | extract 0 "$cwd"
    if [ "${2:-}" = all ]; then
      tmux capture-pane -p -e -J -t "$pane" -S "-$((scroll + hist))" -E "-$((scroll + 1))" | extract 1 "$cwd"
    fi
  } | classify | order
}

opener() {
  if [[ $OSTYPE == darwin* ]]; then open "$1"; else xdg-open "$1"; fi
}

editor() {
  local e="${EDITOR:-}"
  [ -n "$e" ] || e=$(tmux show-environment -g EDITOR 2> /dev/null | cut -s -d= -f2-)
  [ -n "$e" ] || e=$(command -v nvim || echo vi)
  printf '%s' "$e"
}

# Link text -> URL or local path. URLs go through the extractor, so file://
# authorities and %XX escapes are handled in one place; ~ and relative
# paths (a selected `src/main.rs`) resolve against cwd.
normalize() {
  local t="$1" cwd="${2:-$PWD}"
  case "$t" in
    *://*) printf '\033]8;;%s\033\\x\033]8;;\033\\\n' "$t" | extract 0 "$cwd" "" 1 | cut -f5 | head -n 1 ;;
    [~]/*) printf '%s' "$HOME${t#\~}" ;;
    /*) printf '%s' "$t" ;;
    *) printf '%s' "$cwd/$t" ;;
  esac
}

# url, or what classify makes of a local path (empty if it does not exist)
kind_of() {
  case "$1" in
    *://*) echo url ;;
    *) printf '0\t0\t0\tpath\t%s\t\t0\t0\n' "$1" | classify | cut -f4 ;;
  esac
}

# macOS `open` rejects bytes outside RFC 3986's set; encode them instead
url_encode() {
  printf '%s' "$1" | LC_ALL=C gawk '
    BEGIN { RS = "^$"; for (i = 0; i < 256; i++) ord[sprintf("%c", i)] = i }
    { for (i = 1; i <= length($0); i++) {
        ch = substr($0, i, 1)
        if (ch ~ /[A-Za-z0-9._~:\/?#\[\]@!$&()*+,;=%-]/) printf "%s", ch; else printf "%%%02X", ord[ch] } }'
}

open_target() {
  local t kind dir
  t=$(normalize "$1" "${2:-}")
  kind=$(kind_of "$t")
  case "$kind" in
    url) opener "$(url_encode "$t")" ;;
    file | dir)
      if [ -d "$t" ]; then dir=$t; else dir=$(dirname "$t"); fi
      tmux new-window -c "$dir" "$(editor) $(printf '%q' "$t")"
      ;;
    image | binary) opener "$t" ;;
    *) tmux display-message "tmux-links: ${t//#/##} does not exist" ;;
  esac
}

# URL breakdown, plus `gh` for GitHub PRs and issues. Deliberately no fetch
# of arbitrary URLs: hovering must not consume one-time links.
preview_url() {
  local u="$1" lines="$2" cols="$3" rest host path query frag owner repo type num sub out
  rest="${u#*://}"
  path="${rest#"${rest%%[/?#]*}"}"; path="/${path#/}"
  host="${rest%%[/?#]*}"; host="${host##*@}"; host="${host%%:*}"
  frag="${path#*#}"; [ "$frag" = "$path" ] && frag=""; path="${path%%#*}"
  query="${path#*\?}"; [ "$query" = "$path" ] && query=""; path="${path%%\?*}"
  printf '\033[1m%s\033[0m\n%s\n' "$host" "$path"
  [ -z "$query" ] || printf '%s\n' "$query" | tr '&' '\n' | sed 's/^/  ? /'
  [ -z "$frag" ] || printf '  # %s\n' "$frag"
  if [ "$host" != github.com ] || ! command -v gh > /dev/null; then return 0; fi
  IFS=/ read -r _ owner repo type num <<< "$path"
  num="${num%%[!0-9]*}"
  case "$type" in
    pull) sub='pr' ;;
    issues) sub='issue' ;;
    *) return 0 ;;
  esac
  [ -n "$num" ] || return 0
  echo
  # on a tty (the p popup) show progress; under fzf its own spinner does
  if [ -t 1 ]; then printf '\033[2mfetching from GitHub...\033[0m'; fi
  out=$(GH_FORCE_TTY="$cols" gh "$sub" view "$num" -R "$owner/$repo" 2>&1 | gawk -v n="$lines" 'NR <= n') || true
  if [ -t 1 ]; then printf '\r\033[K'; fi
  printf '%s\n' "$out"
}

# Kitty graphics (Ghostty; needs allow-passthrough and macOS sips): print the
# placeholder grid at once, then in the background resample (cached by file
# identity) and hand the PNG to the terminal by path (medium t=f). That is one
# short sequence, so writing it into the tty cannot interleave with fzf's own
# output the way inline image data would; it goes out once fzf has finished
# painting, since tmux drops passthrough while a popup redraw is pending.
preview_image() {
  local t="$1" cols="$2" rows="$3" w h cw ch c r id bg=""
  command -v sips > /dev/null || return 0
  read -r w h <<< "$(sips -g pixelWidth -g pixelHeight "$t" 2> /dev/null | gawk '/pixel/ { printf "%s ", $2 }')"
  [ -n "${h:-}" ] || return 0
  read -r cw ch <<< "$(tmux display-message -p '#{client_cell_width} #{client_cell_height}')"
  read -r c r <<< "$(gawk -v W="$w" -v H="$h" -v C="$cols" -v R="$rows" -v cw="${cw:-8}" -v ch="${ch:-17}" 'BEGIN {
    s = C * cw / W; if (R * ch / H < s) s = R * ch / H
    c = int(W * s / cw + 0.5); r = int(H * s / ch + 0.5)
    print (c < 1 ? 1 : c), (r < 1 ? 1 : r) }')"
  id=$(($$ % 255 + 1))
  # a PDF page has no background of its own; the image is drawn over the cells
  case "$t" in *.[pP][dD][fF]) bg=';48;2;255;255;255' ;; esac
  LC_ALL=C gawk -f "$LIB/kitty.awk" -v dia="$LIB/diacritics.txt" -v id="$id" -v c="$c" -v r="$r" -v bg="$bg"
  (
    # x2: Ghostty reports cell sizes in points; assume a retina display
    max=$((c * ${cw:-8} * 2)); [ $((r * ${ch:-17} * 2)) -gt "$max" ] && max=$((r * ${ch:-17} * 2))
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-links"; mkdir -p "$cache"
    find "$cache" -type f -mtime +30 -delete 2> /dev/null
    png="$cache/$(printf '%s|%s|%s' "$t" "$(stat -L -c %Y_%s -- "$t")" "$max" | md5sum | cut -c1-16).png"
    if [ ! -s "$png" ]; then
      if sips -s format png -Z "$max" "$t" --out "$png.$$" > /dev/null 2>&1; then
        mv -f "$png.$$" "$png"
      else
        rm -f "$png.$$"; exit 0
      fi
    fi
    # DCS tmux; APC ... ST ST, the inner ESCs doubled for tmux
    seq=$(printf '\033Ptmux;\033\033_Ga=T,U=1,f=100,q=2,t=f,i=%s,c=%s,r=%s;%s\033\033%s\033%s' \
      "$id" "$c" "$r" "$(printf '%s' "$png" | base64 -w 0)" "\\" "\\")
    # twice: the first may still land on a pending redraw
    sleep 0.1; printf '%s' "$seq" > /dev/tty; sleep 0.4; printf '%s' "$seq" > /dev/tty
  ) < /dev/null > /dev/null 2>&1 &
}

# preview <target> <kind>, sized by FZF_PREVIEW_COLUMNS/LINES
preview() {
  local t="$1" kind="$2" cols="${FZF_PREVIEW_COLUMNS:-80}" lines="${FZF_PREVIEW_LINES:-40}"
  [ -n "$t" ] || return 0
  case "$kind" in
    file) bat --color=always --paging=never --style=numbers,header --line-range ":$((lines * 2))" -- "$t" ;;
    dir) eza -la --color=always --icons --group-directories-first -- "$t" 2> /dev/null || ls -la -- "$t" ;;
    image)
      preview_image "$t" "$cols" "$((lines - 2))"
      file -b -- "$t"
      ;;
    binary)
      file -b -- "$t"
      du -h -- "$t" | cut -f1
      ;;
    url) preview_url "$t" "$lines" "$cols" ;;
  esac
}

# fzf has no per-item weights, but for equal match scores it falls back to
# input order (--tiebreak=index). So the rows are fed in reading order while
# the query is empty and reloaded sorted by prio (render.awk's 4th field)
# as soon as one is typed: a labelled link outranks a bare one, a file a
# bare URL, and directories come last.
pick() {
  local pane=$1 sel key target
  rows=$(mktemp)   # not local: the EXIT trap runs after this function returns
  trap 'rm -f "${rows:-}"' EXIT
  records "$pane" all | render > "$rows" || true
  if [ ! -s "$rows" ]; then
    tmux display-message "tmux-links: no links in pane"
    return 0
  fi
  sel=$(fzf \
    --tmux center,90%,80% --ansi --tiebreak=index --layout reverse \
    --delimiter "$TAB" --with-nth 1 \
    --preview "$0 preview {2} {3}" \
    --preview-window 'right,50%,wrap,border-left,<70(down,50%,wrap,border-top)' \
    --bind 'ctrl-/:toggle-preview' \
    --bind "change:reload(if [ -n {q} ]; then sort -s -t '$TAB' -k4,4n '$rows'; else cat '$rows'; fi)" \
    --prompt 'link> ' --header 'Enter: open | Ctrl-Y: copy | Ctrl-/: preview | Esc: close' \
    --expect ctrl-y < "$rows") || return 0
  key=$(printf '%s\n' "$sel" | sed -n 1p)
  target=$(printf '%s\n' "$sel" | sed -n 2p | cut -f2)
  [ -n "$target" ] || return 0
  if [ "$key" = ctrl-y ]; then
    printf '%s' "$target" | tmux load-buffer -w -
  else
    open_target "$target"
  fi
}

# Searches for the on-screen text of every link in view: the label, else the
# target. tmux highlights all matches and n/N cycle; the hyperlink attribute
# under the cursor, not the match, decides what open-at opens.
jump() {
  local pane=$1 recs pattern
  recs=$(records "$pane") || true
  if [ -z "$recs" ]; then
    tmux display-message "tmux-links: no links in view"
    return 0
  fi
  # longest first; capped well under tmux's 16 KB command limit
  pattern=$(printf '%s\n' "$recs" | LC_ALL=C gawk -F "$TAB" '
    { s = ($5 != "") ? $5 : $4
      gsub(/[][\\.^$*+?(){}|]/, "\\\\&", s)
      if (!(s in len)) len[s] = length(s) }
    END {
      PROCINFO["sorted_in"] = "@val_num_desc"
      for (s in len) { if (length(out) + len[s] > 12000) break; out = out (out == "" ? "" : "|") s }
      print out }')
  # from the bottom of the view, so the first hit is the last link in it
  [ "$(pane_fmt "$pane" '#{pane_in_mode}')" = 1 ] || tmux copy-mode -t "$pane"
  tmux send-keys -t "$pane" -X bottom-line
  tmux send-keys -t "$pane" -X end-of-line
  tmux send-keys -t "$pane" -X search-backward "$pattern"
}

# The link under the copy-mode cursor: the hyperlink attribute, else a bare
# link on the rendered row (anywhere on disk), else text equal to the label
# of a link in view — jump highlights those too. Empty when none.
target_at() {
  local pane=$1 hl x cwd line bx
  hl=$(pane_fmt "$pane" '#{copy_cursor_hyperlink}')
  if [ -n "$hl" ]; then
    printf '%s' "$hl"
    return
  fi
  # a non-blank separator, so an empty cwd does not shift the fields
  IFS=$'\x1f' read -r x cwd line <<< "$(pane_fmt "$pane" $'#{copy_cursor_x}\x1f#{pane_current_path}\x1f#{copy_cursor_line}')"
  # record offsets are bytes, the cursor column counts characters
  bx=$(LINKS_LINE="$line" LC_ALL=C gawk -v x="$x" 'BEGIN {
    line = ENVIRON["LINKS_LINE"]; n = -1
    for (bx = 1; bx <= length(line) && n < x; bx++) if (substr(line, bx, 1) !~ /[\200-\277]/) n++
    print bx - 2 }')
  printf '%s\n' "$line" | extract 0 "$cwd" "" 1 | classify \
    | gawk -F "$TAB" -v bx="$bx" '$7 <= bx && bx < $8 { print $5; exit }' | grep . \
    || records "$pane" | LINKS_LINE="$line" LC_ALL=C gawk -F "$TAB" -v bx="$bx" '
      BEGIN { line = ENVIRON["LINKS_LINE"] }
      $5 != "" {
        for (p = index(line, $5); p; p = (q = index(substr(line, p + 1), $5)) ? p + q : 0)
          if (p - 1 <= bx && bx < p - 1 + length($5)) { print $4; exit }
      }' || true
}

open_at() {
  local pane=$1 target
  if [ "$(pane_fmt "$pane" '#{selection_present}')" = 1 ]; then
    tmux send-keys -t "$pane" -X pipe-and-cancel "$0 open-piped $(printf '%q' "$(pane_fmt "$pane" '#{pane_current_path}')")"
    return
  fi
  target=$(target_at "$pane")
  if [ -z "$target" ]; then
    tmux display-message "tmux-links: no link under cursor"
    return 0
  fi
  tmux send-keys -t "$pane" -X cancel
  open_target "$target"
}

# Popup size for a preview of <path> of <kind>: as tall as the content up to
# 70% of the client; wide for code, narrow for URLs, images by aspect ratio
popup_size() {
  local kind=$1 t=$2 rows cols cw ch lines w h iw ih
  read -r rows cols cw ch <<< "$(tmux display-message -p '#{client_height} #{client_width} #{client_cell_width} #{client_cell_height}')"
  h=$((rows * 7 / 10))
  case "$kind" in
    file) lines=$(($(wc -l < "$t") + 4)); w=70% ;;
    dir) lines=$(($(find "$t" -mindepth 1 -maxdepth 1 | wc -l) + 5)); w=70% ;;
    url) case "$t" in *github.com/*/*/pull/* | *github.com/*/*/issues/*) lines=$((rows * 6 / 10)) ;; *) lines=10 ;; esac; w=100 ;;
    image)
      lines=$h
      read -r iw ih <<< "$(sips -g pixelWidth -g pixelHeight "$t" 2> /dev/null | gawk '/pixel/ { printf "%s ", $2 }')"
      w=$(gawk -v W="${iw:-4}" -v H="${ih:-3}" -v h="$h" -v cw="${cw:-8}" -v ch="${ch:-17}" -v max="$((cols * 9 / 10))" \
        'BEGIN { w = int(W / H * (h - 4) * ch / cw + 0.5) + 2; print (w > max ? max : w) }')
      ;;
    *) lines=6; w=80 ;;
  esac
  [ "$lines" -lt "$h" ] && h=$lines
  printf '%s %s' "$w" "$h"
}

# The link under the cursor previewed in a popup of its own
preview_at() {
  local pane=$1 target t kind w h
  target=$(target_at "$pane")
  if [ -z "$target" ]; then
    tmux display-message "tmux-links: no link under cursor"
    return 0
  fi
  t=$(normalize "$target" "$(pane_fmt "$pane" '#{pane_current_path}')")
  kind=$(kind_of "$t")
  [ -n "$kind" ] || { tmux display-message "tmux-links: ${t//#/##} does not exist"; return 0; }
  read -r w h <<< "$(popup_size "$kind" "$t")"
  # -T is a format: keep a URL's # literal
  tmux display-popup -E -w "$w" -h "$h" -T " ${target//#/##} " "$0 show $(printf '%q' "$t") $kind"
}

# show <path-or-url> <kind>: runs inside that popup; Enter opens, any other
# key closes
show_target() {
  local t=$1 kind=$2 size key
  size=$(stty size < /dev/tty 2> /dev/null || echo "40 80")
  FZF_PREVIEW_LINES=$((${size% *} - 2)) FZF_PREVIEW_COLUMNS=${size#* } preview "$t" "$kind" || true
  printf '\n\033[2mEnter: open | any key: close\033[0m'
  IFS= read -rsn1 key < /dev/tty
  [ -n "$key" ] || open_target "$t"
}

case "${1:-}" in
  pick) pick "${2:?pane}" ;;
  jump) jump "${2:?pane}" ;;
  open-at) open_at "${2:?pane}" ;;
  preview-at) preview_at "${2:?pane}" ;;
  list) records "${2:?pane}" all | render ;;
  open) open_target "${2:?target}" "${3:-}" ;;
  open-piped) open_target "$(tr -d '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')" "${2:-}" ;;
  show) show_target "${2:?target}" "${3:?kind}" ;;
  preview) preview "${2:-}" "${3:-}" ;;
  *)
    echo "usage: tmux-links pick|jump|open-at|preview-at|list <pane> | open <target> [cwd]" >&2
    exit 2
    ;;
esac
