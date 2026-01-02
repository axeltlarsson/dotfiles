local o = vim.o
local cmd = vim.cmd

-- Theme
cmd.syntax("enable")
o.background = "dark"
o.termguicolors = true

-- UI
o.laststatus = 2
o.updatetime = 100
o.showmode = false
o.number = true
o.relativenumber = true
o.cursorline = true
o.conceallevel = 2
o.hidden = true
o.lazyredraw = true
o.mouse = "n"

-- Folding
o.foldmethod = "expr"
o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
o.foldlevel = 99


-- Search
o.hlsearch = true
o.incsearch = true
o.ignorecase = true
o.smartcase = true

-- Indentation (spaces only)
o.expandtab = true
o.shiftwidth = 2
o.softtabstop = -1 -- follow shiftwidth
o.autoindent = true

vim.g.editorconfig = true

-- Splits / command preview / scrolling
o.splitbelow = true
o.splitright = true
o.inccommand = "nosplit"
o.scrolloff = 2

-- Persistent undo / swap
do
  local state = vim.fn.stdpath("state")
  local undo_dir = state .. "/undo"
  local swap_dir = state .. "/swap"

  vim.fn.mkdir(undo_dir, "p")
  vim.fn.mkdir(swap_dir, "p")

  o.undofile = true
  o.undodir = undo_dir
  o.directory = swap_dir .. "//"
  o.updatecount = 100
  o.undolevels = 1000
  o.undoreload = 10000
end

