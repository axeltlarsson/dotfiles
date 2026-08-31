local o = vim.o
local cmd = vim.cmd

-- Theme
-- 'background' is deliberately NOT set: neovim queries the terminal background
-- (OSC 11) at startup and sets it itself, which picks up ghostty's current
-- light/dark theme (and works over SSH). rose-pine's variant = "auto" then
-- resolves to dawn or main. `theme sync` pushes changes into running instances.
cmd.syntax("enable")
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

-- Custom digraphs (insert with <C-k>)
cmd [[
  digraph =^ 8796
  digraph =D 8797
  digraph := 8788
]]

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

