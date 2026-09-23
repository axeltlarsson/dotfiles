# One record per link on stdin (a `capture-pane -e -J` dump), tab-separated:
#   group  seq  row  kind  target  label  start  end
# kind is url, path (an explicit file:// link) or cand (a bare path that
# still has to be found on disk). start/end are byte offsets into the
# rendered line, for finding the link under the copy-mode cursor.
# Environment: LINKS_CWD, LINKS_HOME, LINKS_IGNORE (ERE dropping targets),
# LINKS_ANYWHERE (accept bare paths outside home and cwd).

BEGIN {
  FS = OFS = "\t"
  cwd = ENVIRON["LINKS_CWD"]; home = ENVIRON["LINKS_HOME"]
  ignore = ENVIRON["LINKS_IGNORE"]; anywhere = ENVIRON["LINKS_ANYWHERE"] != ""
  esc = sprintf("%c", 27); bel = sprintf("%c", 7)
  intro = esc "\\]8;"
  term = esc "\\\\|" bel
  csi = esc "\\[[0-9;:<=>?]*[@-~]"
  scheme = "(https?|ftp|ssh|git|file|postgres(ql)?)://"
  delim = "[ \t'\"<>\\[\\]`\\\\]"
  pathre = "(^|[^A-Za-z0-9_@.+~/\200-\377-])((~|\\.\\.?)?/[A-Za-z0-9_@.+~/\200-\377-]*)"
}

function strip(s) { gsub(csi, "", s); return s }
function trim(s)  { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function blank(n) { return sprintf("%*s", n, "") }

# %XX escapes, except the control characters that would break a record
function pdecode(s,  out, code) {
  out = ""
  while (match(s, /%[0-9A-Fa-f][0-9A-Fa-f]/)) {
    code = strtonum("0x" substr(s, RSTART + 1, 2))
    out = out substr(s, 1, RSTART - 1) (code == 0 || code == 9 || code == 10 || code == 13 ? substr(s, RSTART, 3) : sprintf("%c", code))
    s = substr(s, RSTART + 3)
  }
  return out s
}

function absolute(p) {
  if (p ~ /^~\//) return home substr(p, 2)
  if (p ~ /^\.\//) return cwd substr(p, 2)
  if (p ~ /^\.\.\//) return cwd "/" p
  return p
}

function inside(p, root) { return root != "" && (p == root || index(p, root "/") == 1) }

# a ")" only closes a URL if no "(" inside it is open
function unbalanced(s,  o, c) {
  o = gsub(/\(/, "(", s); c = gsub(/\)/, ")", s)
  return c > o
}

function emit(kind, target, label, start, end) {
  if (target == "" || target ~ /[\t\n]/ || (ignore != "" && target ~ ignore)) return
  if (label == target) label = ""
  print group, ++seq, NR, kind, target, label, start, end
}

# file:// targets (any authority) become paths and get the on-disk treatment
function emit_url(url, label, start, end,  p) {
  if (url ~ /^file:\/\//) {
    p = url; sub(/^file:\/\/[^\/]*/, "", p)
    p = pdecode(p)
    emit("path", p, label == url ? "" : label, start, end)
  } else emit("url", url, label, start, end)
}

{
  # OSC 8: split on the introducer; each chunk is "params;URI<ST>label..."
  n = split($0, part, intro)
  text = strip(part[1])
  for (i = 2; i <= n; i++) {
    chunk = part[i]
    if (!match(chunk, term)) { text = text strip(chunk); continue }
    head = substr(chunk, 1, RSTART - 1)
    rest = strip(substr(chunk, RSTART + RLENGTH))
    s = index(head, ";")
    url = s ? substr(head, s + 1) : ""
    sub(esc ".*", "", url)
    if (url == "") { text = text rest; continue }
    start = length(text)
    emit_url(url, trim(rest), start, start + length(rest))
    text = text blank(length(rest))
  }

  # bare URLs: run to a delimiter, then trim trailing punctuation
  pos = 1
  while (match(substr(text, pos), scheme)) {
    start = pos + RSTART - 1
    rest = substr(text, start)
    len = match(rest, delim) ? RSTART - 1 : length(rest)
    cand = substr(rest, 1, len)
    while (cand ~ /[.,:;!?]$/ || (cand ~ /\)$/ && unbalanced(cand))) cand = substr(cand, 1, length(cand) - 1)
    if (cand !~ /:\/\/$/) emit_url(cand, cand, start - 1, start - 1 + length(cand))
    text = substr(text, 1, start - 1) blank(len) substr(text, start + len)
    pos = start + len
  }

  # bare paths, under home or the pane's cwd unless told otherwise;
  # existence is checked later
  pos = 1
  while (match(substr(text, pos), pathre, m)) {
    raw = m[2]
    start = pos + RSTART - 1 + length(m[1])
    pos = start + length(raw)
    while (raw ~ /[^A-Za-z0-9_@+~\200-\377-]$/) raw = substr(raw, 1, length(raw) - 1)
    if (length(raw) < 2) continue
    abs = absolute(raw)
    if (!anywhere && !inside(abs, home) && !inside(abs, cwd)) continue
    emit("cand", abs, raw, start - 1, start - 1 + length(raw))
  }
}
