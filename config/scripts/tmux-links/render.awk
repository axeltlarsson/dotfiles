# Ordered records -> fzf rows: "<icon>  <label>  <dim target>\t<target>\t<kind>\t<prio>".
# prio ranks what a typed query should prefer among equal matches: a
# labelled link over a bare one, a file over a bare URL, a directory last.
# Runs under LC_ALL=C. width() counts a UTF-8 character as its bytes minus
# continuation bytes: one cell each, which is how tmux lays them out. That
# holds for BMP nerd-font glyphs; icons.tsv avoids emoji and supplementary-
# plane icons, which tmux still sizes at one cell but the terminal draws two.

BEGIN {
  FS = "\t"
  esc = sprintf("%c", 27); dim = esc "[2m"; off = esc "[0m"
  while ((getline l < icons) > 0) { split(l, a, "\t"); ic[a[1]] = a[2] }
  close(icons)
  maxpad = 50
}

function width(s) { return length(s) - gsub(/[\200-\277]/, "", s) }

# host, then the extension of the final path element, then kind
function icon(kind, target,  host, e) {
  if (kind == "url") {
    host = target
    sub(/^[a-z+]+:\/\//, "", host); sub(/[\/:?#].*/, "", host); sub(/^www\./, "", host)
    if (("host:" host) in ic) return ic["host:" host]
    e = target; sub(/^[a-z+]+:\/\/[^\/]*/, "", e)
  } else e = target
  sub(/[?#].*/, "", e); sub(/.*\//, "", e)
  if (kind != "dir" && e ~ /^.+\.[A-Za-z0-9]+$/) {
    sub(/.*\./, "", e); e = tolower(e)
    if (("ext:" e) in ic) return ic["ext:" e]
  }
  return ("kind:" kind) in ic ? ic["kind:" kind] : " "
}

{
  n++
  grp[n] = $1; kind[n] = $3; tgt[n] = $4; lab[n] = $5
  w = width(lab[n]); if (w > pad) pad = w
}

END {
  if (pad > maxpad) pad = maxpad
  for (i = 1; i <= n; i++) {
    if (grp[i] == 1 && i > 1 && grp[i - 1] == 0)
      print dim "  ── history ──" off "\t\t\t9"
    row = icon(kind[i], tgt[i]) "  "
    if (lab[i] == "") row = row tgt[i]
    else {
      gap = pad - width(lab[i]) + 2; if (gap < 2) gap = 2
      row = row lab[i] sprintf("%*s", gap, "") dim tgt[i] off
    }
    prio = lab[i] != "" ? 0 : kind[i] == "dir" ? 3 : kind[i] == "url" ? 2 : 1
    print row "\t" tgt[i] "\t" kind[i] "\t" prio
  }
}
