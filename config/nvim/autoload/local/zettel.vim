func! local#zettel#edit(...)

  " build the file name
  let l:sep = ''
  if len(a:000) > 0
    let l:sep = '-'
  endif
  let l:fname = expand('~/notes/') . strftime("%Y%m%d%H%M") . l:sep . join(a:000, '_') . '.md'

  " edit the new file
  exec "e " . l:fname

  " enter the title and timestamp (using ultisnips) in the new file
  if len(a:000) > 0
    exec "silent! normal I# " . join(a:000) . "\<cr>\<esc>"
  endif
endfunc
