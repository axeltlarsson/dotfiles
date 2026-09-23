# Rewrites kind from one batched stat over every path candidate: url stays
# url, a path that exists becomes file, dir, image or binary, and one that
# does not is dropped. Candidates go through a file, not a coprocess: with
# nothing to write a coprocess never opens and the read side hangs, and a
# large batch deadlocks on the pipe.

BEGIN {
  FS = OFS = "\t"
  # image: anything sips can rasterise for a preview, so PDFs too
  image  = " png jpg jpeg gif webp svg bmp ico avif heic tif tiff pdf "
  binary = " zip gz xz zst tar 7z dmg pkg mp3 mp4 mkv mov wav ogg webm" \
           " docx xlsx pptx odt epub ttf otf woff woff2 so dylib bin exe wasm "
}

function ext(p) {
  sub(/.*\//, "", p)
  if (p !~ /^.+\./) return ""
  sub(/.*\./, "", p)
  return tolower(p)
}

{
  rec[NR] = $0
  if ($4 != "url") cand[$5]
}

END {
  if (length(cand)) {
    tmp = (ENVIRON["TMPDIR"] != "" ? ENVIRON["TMPDIR"] : "/tmp") "/tmux-links." PROCINFO["pid"]
    for (p in cand) printf "%s\0", p > tmp
    close(tmp)
    cmd = "xargs -0 stat -L -c '%n\t%F' -- < '" tmp "' 2> /dev/null"
    while ((cmd | getline l) > 0) { split(l, a, "\t"); type[a[1]] = a[2] }
    close(cmd)
    system("rm -f '" tmp "'")
  }
  for (i = 1; i <= NR; i++) {
    $0 = rec[i]
    if ($4 == "url") { print; continue }
    if (!($5 in type)) continue
    if (type[$5] == "directory") $4 = "dir"
    else if (type[$5] !~ /regular/) $4 = "binary"   # fifos, sockets, devices: never read them
    else {
      e = " " ext($5) " "
      $4 = index(image, e) ? "image" : index(binary, e) ? "binary" : "file"
    }
    print
  }
}
