" Automatically install vim-plug
if has('nvim')
  if empty(glob('~/.local/share/nvim/site/autoload/plug.vim'))
    silent !curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs
          \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
  endif
elseif
  if empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
          \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
  endif
endif

" ---- Plugins ----
call plug#begin('~/.vim/plugged')

let g:polyglot_disabled = ['elm'] " Zaptic/elm-vim covers this better
" let g:elm_setup_keybindings = 0

Plug 'Chiel92/vim-autoformat'
Plug 'LnL7/vim-nix'
Plug 'SirVer/ultisnips'
" Plug 'Zaptic/elm-vim'
Plug 'airblade/vim-gitgutter'
Plug 'editorconfig/editorconfig-vim'
Plug 'godlygeek/tabular'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': { -> fzf#install() } } " Installs fzf as system command
Plug 'junegunn/fzf.vim'
Plug 'junegunn/goyo.vim'                " Distraction-free writing
Plug 'junegunn/limelight.vim'           " Hyperfocus-writing
Plug 'lambdalisue/fern-renderer-nerdfont.vim'
Plug 'lambdalisue/fern.vim'
Plug 'lambdalisue/glyph-palette.vim'
Plug 'lambdalisue/nerdfont.vim'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'neovim/nvim-lspconfig'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.0' }
" Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'arch -arm64 make' }
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}  " We recommend updating the parsers on update
Plug 'pangloss/vim-javascript'
Plug 'plasticboy/vim-markdown'
Plug 'reedes/vim-pencil'
Plug 'rose-pine/neovim'
Plug 'scrooloose/nerdcommenter'
Plug 'sheerun/vim-polyglot'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'vim-scripts/bats.vim'
Plug 'w0rp/ale'                         " For LSP
Plug 'yazgoo/unicodemoji'
call plug#end()

"Use 24-bit (true-color) mode in Vim/Neovim
if (has("nvim"))
  "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
  let $NVIM_TUI_ENABLE_TRUE_COLOR=1
endif
"For Neovim > 0.1.5 and Vim > patch 7.4.1799 < https://github.com/vim/vim/commit/61be73bb0f965a895bfb064ea3e55476ac175162 >
"Based on Vim patch 7.4.1770 (`guicolors` option) < https://github.com/vim/vim/commit/8a633e3427b47286869aa4b96f2bfc1fe65b25cd >
" < https://github.com/neovim/neovim/wiki/Following-HEAD#20160511 >
if (has("termguicolors"))
  set termguicolors
endif
set t_8f=[38;2;%lu;%lu;%lum
set t_8b=[48;2;%lu;%lu;%lum

" Theme
syntax enable
set background=dark
colorscheme rose-pine

" always show the status bar
set laststatus=2

" Airline
let g:airline_powerline_fonts = 1
let g:airline_theme='hybrid'

" gitgutter
set updatetime=100

set noshowmode     " do not display" -- INSERT -- " since that is unnecessary with airline
set encoding=utf8
set hlsearch
set incsearch
set number
set relativenumber
set cursorline     " highlight current line
set conceallevel=2
set nocompatible   " be iMproved, required
set hidden         " allow multiple files to be opened in diff buffers, 'hidden' in bg

set nofoldenable

" For indentation w/o tabs, principle is to set expandtab, and set shiftwidth
" and softtabstop to the same value, leaving tabstop at default (8)
set expandtab       " inserts `softtabstop` amount of space chars
set shiftwidth=2    " indentation, (<<,>>, ==)
set softtabstop=2   " insert 2 spaces
" Set lazyredraw for better performance when scrolling
set lazyredraw

" More natural splits
set splitbelow
set splitright

set inccommand=nosplit
set scrolloff=2

" Clear highlighting on escape in Normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

" Rebind leader key
map <space> <Leader>
set autoindent

set mouse=n

" Search current word with Rg
set keywordprg=:Rg

" override polyglot's vim-ruby "ri"
autocmd FileType ruby,eruby,haml set keywordprg=:Rg

" FZF: invoke the :Files with Ctrl+P
nnoremap <C-p> :Files<cr>
nnoremap <silent> <Leader><Space> :Files<CR>
if has('nvim-0.4.0') || has("patch-8.2.0191")
    let g:fzf_layout = { 'window': {
                \ 'width': 0.9,
                \ 'height': 0.7,
                \ 'highlight': 'Comment',
                \ 'rounded': v:false } }
else
    let g:fzf_layout = { "window": "silent botright 16split enew" }
endif

map <Leader>r :Rg<CR>
nnoremap <Leader>b :Buffers<CR>

" Customize fzf colors to match your color scheme
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }


" Insert mode completion TODO: read up on this
imap <c-x><c-k> <plug>(fzf-complete-word)
imap <c-x><c-f> <plug>(fzf-complete-path)
" imap <c-x><c-l> <plug>(fzf-complete-line)

" Move lines down with Ctrl-J and up with Ctrl-K
nnoremap <C-j> :m .+1<CR>==
nnoremap <C-k> :m .-2<CR>==

inoremap <C-j> <ESC>:m .+1<CR>==gi
inoremap <C-k> <ESC>:m .-2<CR>==gi
vnoremap <C-j> :m '>+1<CR>gv=gv
vnoremap <C-k> :m '<-2<CR>gv=gv

nnoremap <Leader>w :w<CR>
nnoremap <Leader>x :x<CR>
nnoremap <Leader>q :q<CR>
nnoremap <Leader>Q :q!<CR>

nnoremap <Leader>l :ALEFix<CR>

map ö [
map ä ]

nmap <Leader>u :Unicodemoji<CR>

" Notes
nnoremap <Leader>ni :e $NOTES_DIR/index.md<CR>:cd $NOTES_DIR<CR>
nnoremap <Leader>nz :Zet<space>

" Searching for notes from anywhere
nnoremap <silent> <Leader>ns :Notes<CR>

" TODO: don't die if $NOTES_DIR not defined
command! -bang -nargs=* Notes
  \ call fzf#vim#grep(
  \   'rg --column --line-number --no-heading --color=always --smart-case -- '.shellescape(<q-args>), 1,
  \   fzf#vim#with_preview({'dir': '${NOTES_DIR}/'}), <bang>0)


" Map leader g to Ctrl-] - to follow links in vim docs
nnoremap <Leader>g <C-]>

" Fern
let g:fern#renderer = "nerdfont"
noremap <silent> <Leader>d :Fern . -drawer -width=35 -toggle<CR><C-w>=
noremap <silent> <Leader>f :Fern . -drawer -reveal=% -width=35<CR><C-w>=
noremap <silent> <Leader>. :Fern %:h -drawer -width=35<CR><C-w>=

function! FernInit() abort
  set nonu
  nmap <buffer><expr>
        \ <Plug>(fern-my-open-expand-collapse)
        \ fern#smart#leaf(
        \   "\<Plug>(fern-action-open:select)",
        \   "\<Plug>(fern-action-expand)",
        \   "\<Plug>(fern-action-collapse)",
        \ )
  nmap <buffer> <CR> <Plug>(fern-my-open-expand-collapse)
  nmap <buffer> <2-LeftMouse> <Plug>(fern-my-open-expand-collapse)
  nmap <buffer> m <Plug>(fern-action-mark-toggle)j
  nmap <buffer> N <Plug>(fern-action-new-file)
  nmap <buffer> K <Plug>(fern-action-new-dir)
  nmap <buffer> D <Plug>(fern-action-remove)
  nmap <buffer> R <Plug>(fern-action-move)
  nmap <buffer> s <Plug>(fern-action-open:split)
  nmap <buffer> v <Plug>(fern-action-open:vsplit)
  nmap <buffer> r <Plug>(fern-action-reload)
  nmap <buffer> q :q<CR>
  nmap <buffer> <nowait> d <Plug>(fern-action-hidden-toggle)j
  nmap <buffer> <nowait> < <Plug>(fern-action-leave)
  nmap <buffer> <nowait> > <Plug>(fern-action-enter)
endfunction

augroup FernGroup
  autocmd!
  autocmd FileType fern call FernInit()
  autocmd FileType fern call glyph_palette#apply()
augroup END

" Copy to clipboard
vnoremap  <leader>y  "+y
nnoremap  <leader>Y  "+yg_
nnoremap  <leader>y  "+y
nnoremap  <leader>yy  "+yy

" Paste from clipboard
nnoremap <leader>p "+p
nnoremap <leader>P "+P
vnoremap <leader>p "+p
vnoremap <leader>P "+P

" Persistent undo
if exists('*mkdir') && !isdirectory($HOME.'/.vim/history')
  call mkdir($HOME.'/.vim/history')
endif
set undofile                    " Save undo's after file closes
set undodir=$HOME/.vim/history  " where to save undo histories
set undolevels=1000             " How many undos
set undoreload=10000            " number of lines to save for undo
set updatecount=100
set directory=$HOME/.vim/history/swap//


" Autoformat
let g:ale_enable = 0
let g:autoformat_verbosemode = 0
let g:formatters_python = ['black']

" ALE
let g:ale_fixers = {'python': ['black', 'isort'], 'sql': ['pgformatter'], 'json': ['jq'], 'haskell': ['ormolu'], 'javascript': ['eslint'], 'markdown': ['prettier'], 'nix': ['nixfmt'], 'ruby': ['rufo']}
let g:ale_linters = {'python': ['flake8', 'mypy'], 'sql': ['sqlint'], 'javascript': ['prettier', 'eslint'], 'ruby': ['rubocop']}
let g:ale_sql_pgformatter_options = '-g -s 2 -U 1 -u 1 -w 100'
let g:ale_python_auto_pipenv = 1
let g:ale_python_mypy_options = '--follow-imports skip'

let g:ale_fix_on_save = 1
" let g:ale_set_loclist = 0
" let g:ale_set_quickfix = 1
" let g:ale_open_list = 1
let g:airline#extensions#ale#enabled = 1

" NERDCommenter adds spaces after comment delimiters by default
let g:NERDSpaceDelims = 1

" vim-markdown
let g:vim_markdown_folding_disabled = 0
let g:vim_markdown_new_list_item_indent = 2
let g:vim_markdown_strikethrough = 1
let g:vim_markdown_math = 1

" Zen Mode
autocmd! User GoyoEnter Limelight
autocmd! User GoyoLeave Limelight!

" Set syntax error for nbsp, except for NERDTree
fun! SyntaxErrorOnNbsp()
  " Don't do it for NERDTree
  if &ft =~ 'fern'
    return
  endif
  call matchadd("Error", " ", -1)
endfun

autocmd BufEnter,WinEnter * call SyntaxErrorOnNbsp()

" snippets
let g:UltiSnipsSnippetDirectories=[$HOME.'/.config/nvim/UltiSnips']

" Trigger configuration. Do not use <tab> if you use https://github.com/Valloric/YouCompleteMe.
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<tab>"
let g:UltiSnipsJumpBackwardTrigger="<s-tab>"

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"

" Edit vimrc with :Vimrc (change to :vs to open in a new split)
command! Vimrc :e $MYVIMRC

" TreeSitter
lua <<EOF
-- N.B! CC needs to be unset (not set to clang as in nix shells)
vim.env.CC = ''
require('nvim-treesitter.configs').setup {
  -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  ensure_installed = {
    "bash",
    "comment",
    "css",
    "elm",
    "haskell",
    "html",
    "javascript",
    "json",
    "lua",
    "nix",
    "python",
    "ruby",
    "sql",
    "vim",
  },

  highlight = {
    enable = true;
  },
}
EOF

" LSP
lua <<EOF
-- Mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
local opts = { noremap=true, silent=true }
vim.keymap.set('n', ',e', vim.diagnostic.open_float, opts)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
vim.keymap.set('n', ',q', vim.diagnostic.setloclist, opts)

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap=true, silent=true, buffer=bufnr }
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
  vim.keymap.set('n', ',wa', vim.lsp.buf.add_workspace_folder, bufopts)
  vim.keymap.set('n', ',wr', vim.lsp.buf.remove_workspace_folder, bufopts)
  vim.keymap.set('n', ',wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, bufopts)
  vim.keymap.set('n', ',D', vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', ',rn', vim.lsp.buf.rename, bufopts)
  vim.keymap.set('n', ',ca', vim.lsp.buf.code_action, bufopts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
  vim.keymap.set('n', ',f', vim.lsp.buf.formatting, bufopts)
end

local lsp_flags = {
  -- This is the default in Nvim 0.7+
  debounce_text_changes = 150,
}
require('lspconfig')['solargraph'].setup{}
require('lspconfig')['elmls'].setup{}

EOF

" Telescope
lua <<EOF

-- You dont need to set any of these options. These are the default ones. Only
-- the loading is important
require('telescope').setup {
  extensions = {
    fzf = {
      fuzzy = true,                    -- false will only do exact matching
      override_generic_sorter = true,  -- override the generic sorter
      override_file_sorter = true,     -- override the file sorter
      case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
                                       -- the default case_mode is "smart_case"
    }
  }
}
-- To get fzf loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
-- TODO: doesn't work properly for whatever reasone
--require('telescope').load_extension('fzf')

EOF
