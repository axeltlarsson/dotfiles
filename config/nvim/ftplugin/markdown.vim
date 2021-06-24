" make link to other notes
function! s:make_note_link(file)
  " TODO: filename is absolute...
    let filename = fnameescape(join(a:file))
    let filename_wo_timestamp = fnameescape(fnamemodify(join(a:file), ":t:s/^[0-9]*-//"))
     " Insert the markdown link to the file in the current buffer
    let mdlink = "[". filename_wo_timestamp ."](".filename.")"
    return mdlink
endfunction

inoremap <expr> <c-t> fzf#vim#complete(fzf#vim#with_preview(fzf#wrap({
  \ 'source':  'rg --smart-case --no-line-number --files ./',
  \ 'reducer': function('<sid>make_note_link') })))
