au FileType gitcommit set tw=72
set nocompatible                " be iMproved, required
filetype off                    " required
set hidden                      " allow multiple files to be opened in diff buffers, 'hidden' in bg
" For indentation w/o tabs, principle is to set expandtab, and set shiftwidth
" and softtabstop to the same value, leaving tabstop at default
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
Plugin 'altercation/vim-colors-solarized'
Plugin 'w0ng/vim-hybrid'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'derekwyatt/vim-scala'
Plugin 'scrooloose/nerdtree'
Plugin 'ctrlp.vim'
Plugin 'scrooloose/nerdcommenter'
Plugin 'pangloss/vim-javascript'
Plugin 'abolish.vim'
Plugin 'suan/vim-instant-markdown'
Plugin 'editorconfig/editorconfig-vim'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line
"

" Set scala-docstrings
let g:scala_scaladoc_indent = 1

" Highlight characters that go over 80 columns
highlight OverLength ctermbg=red ctermfg=white guibg=#592929
autocmd BufNewFile,BufRead *.* match OverLength /\%81v.\+/
autocmd BufNewFile,BufRead *.scala match OverLength /\%121v.\+/
autocmd BufNewFile,BufRead *.html  match OverLength /\%251v.\+/
autocmd BufNewFile,BufRead *.js  match OverLength /\%251v.\+/

set laststatus=2                    " always show the status bar
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

