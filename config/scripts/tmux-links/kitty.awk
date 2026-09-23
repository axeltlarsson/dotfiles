# The kitty graphics placeholder grid for an image: r rows of c cells of
# U+10EEEE, each tagged with its row and column diacritic, the foreground
# colour carrying the image id (bg= adds SGR parameters, e.g. a white
# background under a transparent PDF page). The terminal binds these cells
# to whatever image is later transmitted under that id, so the data can
# follow separately. dia= is kitty's row/column diacritics table, one hex
# codepoint per line; the grid is clamped to its size.

function utf8(cp) {
  if (cp < 128) return sprintf("%c", cp)
  if (cp < 2048) return sprintf("%c%c", 192 + int(cp / 64), 128 + cp % 64)
  if (cp < 65536) return sprintf("%c%c%c", 224 + int(cp / 4096), 128 + int(cp / 64) % 64, 128 + cp % 64)
  return sprintf("%c%c%c%c", 240 + int(cp / 262144), 128 + int(cp / 4096) % 64, 128 + int(cp / 64) % 64, 128 + cp % 64)
}

BEGIN {
  esc = sprintf("%c", 27)
  while ((getline l < dia) > 0) d[n++] = utf8(strtonum("0x" l))
  close(dia)
  if (c > n) c = n
  if (r > n) r = n
  ph = utf8(strtonum("0x10EEEE"))
  for (i = 0; i < r; i++) {
    row = esc "[38;5;" id bg "m"
    for (j = 0; j < c; j++) row = row ph d[i] d[j]
    print row esc "[0m"
  }
}
