au FileType gitcommit set tw=72
set nocompatible                " be iMproved, required
filetype off                    " required
set hidden                      " allow multiple files to be opened in diff buffers, 'hidden' in bg

" and softtabstop to the same value, leaving tabstop at default
" For indentation w/o tabs, principle is to set expandtab, and set shiftwidth
set expandtab
set shiftwidth=2
set softtabstop=2

" ---- Vundle ----
" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
Plugin 'w0ng/vim-hybrid'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'derekwyatt/vim-scala'
Plugin 'scrooloose/nerdtree'
Plugin 'ctrlp.vim'
Plugin 'pangloss/vim-javascript'
Plugin 'abolish.vim'
Plugin 'scrooloose/nerdcommenter'
Plugin 'suan/vim-instant-markdown'
Plugin 'editorconfig/editorconfig-vim'
Plugin 'shougo/deoplete.nvim'
Plugin 'mileszs/ack.vim'
Plugin 'benekastah/neomake'
Plugin 'zchee/deoplete-jedi'
Plugin 'Chiel92/vim-autoformat'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on

" Set scala-docstrings
let g:scala_scaladoc_indent = 1

" Highlight characters that go over 80 columns
highlight OverLength ctermbg=red ctermfg=white guibg=#592929
autocmd BufNewFile,BufRead *.* match OverLength /\%81v.\+/
autocmd BufNewFile,BufRead *.scala match OverLength /\%121v.\+/
autocmd BufNewFile,BufRead *.html  match OverLength /\%251v.\+/
autocmd BufNewFile,BufRead *.js  match OverLength /\%251v.\+/

" always show the status bar
set laststatus=2

" Airline commands
let g:airline_powerline_fonts = 1
let g:airline_theme='base16'

" Theme
syntax enable
set background=dark
colorscheme hybrid
set termguicolors

let g:hybrid_custom_term_colors = 1
set hlsearch
set incsearch
set number

" Clear highlighting on escape in Normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

" Rebind leader key
let mapleader = ","
set autoindent

" CtrlP: Ignore dirs from .gitignore for
let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files -co --exclude-standard']

" Move lines down with Ctrl-J and up with Ctrl-K
nnoremap <C-j> :m .+1<CR>==
nnoremap <C-k> :m .-2<CR>==

inoremap <C-j> <ESC>:m .+1<CR>==gi
inoremap <C-k> <ESC>:m .-2<CR>==gi

vnoremap <C-j> :m '>+1<CR>gv=gv
vnoremap <C-k> :m '<-2<CR>gv=gv

" Add spaces after comment delimiters by default
let g:NERDSpaceDelims = 1

" The Silver Searcher
if executable('ag')
  " Use ag over grep
  let g:ackprg = 'ag --vimgrep'
  " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
  let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'

  " ag is fast enough that CtrlP doesn't need to cache
  let g:ctrlp_use_caching = 0
endif

" Use deoplete
let g:deoplete#enable_at_startup = 1

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
set updatecount =100
set directory   =$HOME/.vim/history/swap//

set cursorline              " Highlight current line
" Neomake linters
let g:neomake_javascript_enabled_makers = ['eslint'] " npm install eslint
let g:neomake_python_enabled_markers = ['pep8'] " apt-get install pep8

" Autoformat
let g:formatter_yapf_style = 'pep8' " pip install yapf
