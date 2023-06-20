" Vim syntax file
" Add checkboxes to *.md files
" source: https://gist.github.com/huytd/668fc018b019fbc49fa1c09101363397

" Custom conceal
call matchadd('Conceal', '\[\ \]', 0, -1, {'conceal': '󰝣'})
call matchadd('Conceal', '\[x\]', 0, -1, {'conceal': '󰡖'})
" 
" ×
" 
" - 󰡖 hej
" - 󰝣 hej
" 󰈜
highlight Conceal ctermbg=NONE ctermfg=NONE guibg=NONE guifg=NONE

setlocal cole=1
