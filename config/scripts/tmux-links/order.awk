# Dedupes on target. Group 0 (visible) keeps reading order, group 1
# (history) runs newest first, and a target in both is listed once, in
# group 0. The longest label seen wins. Output: group seq kind target label

BEGIN { FS = OFS = "\t" }

{
  k = $5
  if (length($6) > length(lab[k])) lab[k] = $6
  kind[k] = $4
  if ($1 == 0) { if (!(k in g0)) g0[k] = $2 }
  else g1[k] = $2
}

END {
  PROCINFO["sorted_in"] = "@val_num_asc"
  for (k in g0) print 0, g0[k], kind[k], k, lab[k]
  PROCINFO["sorted_in"] = "@val_num_desc"
  for (k in g1) if (!(k in g0)) print 1, g1[k], kind[k], k, lab[k]
}
