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

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'


Plugin 'Chiel92/vim-autoformat'
Plugin 'abolish.vim'                      " Case coercion
Plugin 'derekwyatt/vim-scala'
Plugin 'editorconfig/editorconfig-vim'
Plugin 'godlygeek/tabular'
Plugin 'junegunn/fzf'
Plugin 'junegunn/fzf.vim'
Plugin 'mileszs/ack.vim'                  " Search, fast, see SilverSearcher
Plugin 'mxw/vim-jsx'
Plugin 'neomake/neomake'
Plugin 'pangloss/vim-javascript'
Plugin 'ryanoasis/vim-devicons'
Plugin 'scrooloose/nerdcommenter'
Plugin 'scrooloose/nerdtree'
Plugin 'sheerun/vim-polyglot'
Plugin 'shougo/deoplete.nvim'             " Async completion fw for neovim
Plugin 'skwp/greplace.vim'
Plugin 'plasticboy/vim-markdown'
Plugin 'tpope/vim-repeat'
Plugin 'tpope/vim-surround'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'w0ng/vim-hybrid'                  " Colorscheme
Plugin 'zchee/deoplete-jedi'              " Autocompletion, static anal for Python
set encoding=utf8

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required

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
let g:airline_theme='tomorrow'

" Theme
syntax enable
set background=dark
colorscheme hybrid

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

" Add spaces after comment delimiters by default
let g:NERDSpaceDelims = 1

" The Silver Searcher
if executable('ag')
  " Use ag over grep
  let g:ackprg = 'ag --vimgrep'
  let g:grep_cmd_opts = '--line-numbers --noheading'
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
set updatecount=100
set directory=$HOME/.vim/history/swap//

" Highlight current line
set cursorline

" Set lazyredraw for better performance when scrolling
set lazyredraw

" Neomake linters
let g:neomake_javascript_enabled_makers = ['eslint'] " npm install -g eslint
let g:neomake_python_enabled_markers = ['pep8'] " apt-get install pep8
" Call Neomake automatically when writing a buffer.
call neomake#configure#automake('w')

" Autoformat
let g:formatter_yapf_style = 'pep8' " pip install yapf

" Open NERDTree automatically if directory specified (i.e. vim .)
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | endif
let NERDTreeMinimalUI = 1

" vim-markdown
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_new_list_item_indent = 2

" Set syntax error for nbsp, except for NERDTree
fun! SyntaxErrorOnNbsp()
  " Don't do it for NERDTree
  if &ft =~ 'nerdtree'
    return
  endif
  call matchadd("Error", " ", -1)
endfun

autocmd BufEnter,WinEnter * call SyntaxErrorOnNbsp()

