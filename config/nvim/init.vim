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

Plug 'Alok/notational-fzf-vim'
Plug 'Chiel92/vim-autoformat'
Plug 'Zaptic/elm-vim'
Plug 'airblade/vim-gitgutter'
Plug 'editorconfig/editorconfig-vim'
Plug 'godlygeek/tabular'
Plug 'jiangmiao/auto-pairs'
" Installs fzf as system command
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/goyo.vim'                " Distraction-free writing
Plug 'junegunn/limelight.vim'           " Hyperfocus-writing
Plug 'mxw/vim-jsx'
Plug 'pangloss/vim-javascript'
Plug 'plasticboy/vim-markdown'
Plug 'reedes/vim-pencil'
Plug 'ryanoasis/vim-devicons'
Plug 'scrooloose/nerdcommenter'
Plug 'scrooloose/nerdtree'
Plug 'sheerun/vim-polyglot'
Plug 'shougo/deoplete.nvim'             " Async completion fw for neovim
Plug 'skwp/greplace.vim'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'vim-scripts/bats.vim'
Plug 'w0ng/vim-hybrid'                  " Colorscheme
Plug 'w0rp/ale'                         " For LSP
Plug 'zchee/deoplete-jedi'              " Autocompletion, static anal for Python
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
colorscheme hybrid
" let g:hybrid_custom_term_colors = 1

" always show the status bar
set laststatus=2

" Airline commands
let g:airline_powerline_fonts = 1
let g:airline_theme='hybrid'

" gitgutter
set updatetime=100

set noshowmode " do not display "-- INSERT --" since that is unnecessary with airline
set encoding=utf8
set hlsearch
set incsearch
set number
set cursorline " highlight current line
set conceallevel=2
set nocompatible                " be iMproved, required
set hidden                      " allow multiple files to be opened in diff buffers, 'hidden' in bg

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
let mapleader = ","
set autoindent

set mouse=n

" Search current word with Rg
set keywordprg=:Rg

" override polyglot's vim-ruby "ri"
autocmd FileType ruby,eruby,haml set keywordprg=:Rg

" FZF: invoke it with Ctrl+P
nnoremap <C-p> :FZF<cr>

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


" Move lines down with Ctrl-J and up with Ctrl-K
nnoremap <C-j> :m .+1<CR>==
nnoremap <C-k> :m .-2<CR>==

inoremap <C-j> <ESC>:m .+1<CR>==gi
inoremap <C-k> <ESC>:m .-2<CR>==gi
vnoremap <C-j> :m '>+1<CR>gv=gv
vnoremap <C-k> :m '<-2<CR>gv=gv


" NERDCommenters add spaces after comment delimiters by default
let g:NERDSpaceDelims = 1

" Use deoplete
" let g:deoplete#enable_at_startup = 1

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
let g:autoformat_verbosemode = 0
let g:formatters_python = ['black'] " pip install black

let g:ale_fixers = {'python': ['black', 'isort'], 'sql': ['pgformatter']} " pip install black isort && brew install pgformatter
let g:ale_linters = {'python': ['flake8'], 'sql': ['sqlint']}
let g:ale_sql_pgformatter_options = '-g -s 2 -U 1 -u 1 -w 100'
let g:ale_fix_on_save = 1

" Open NERDTree automatically if directory specified (i.e. vim .)
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | endif
let NERDTreeMinimalUI = 1

" vim-markdown
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_new_list_item_indent = 2
let g:vim_markdown_math = 1

" Zen Mode
autocmd! User GoyoEnter Limelight
autocmd! User GoyoLeave Limelight!

" Set syntax error for nbsp, except for NERDTree
fun! SyntaxErrorOnNbsp()
  " Don't do it for NERDTree
  if &ft =~ 'nerdtree'
    return
  endif
  call matchadd("Error", " ", -1)
endfun

autocmd BufEnter,WinEnter * call SyntaxErrorOnNbsp()

" notational-fzf-vim
let g:nv_search_paths = ['../notes', './notes', '~/notes']

" polyglot
let g:polyglot_disabled = ['elm'] " Zaptic/elm-vim covers this better

let g:python3_host_prog='/Users/axel/.pyenv/versions/py3neovim/bin/python'
let g:python_host_prog='/Users/axel/.pyenv/versions/py2neovim/bin/python'

" Edit vimrc with :Vimrc (change to :vs to open in a new split)
command! Vimrc :e $MYVIMRC