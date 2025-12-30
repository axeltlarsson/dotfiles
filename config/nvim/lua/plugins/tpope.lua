return {
  -- Git porcelain in Vim TODO maybe replace with neogit?
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "G", "Gdiffsplit", "Gread", "Gwrite", "Ggrep", "GMove", "GDelete", "GBrowse" }
  },

  -- Repeat plugin-defined mappings with .
  {
    "tpope/vim-repeat",
    event = "VeryLazy"
  },

  -- Surroundings: cs, ds, ys, etc.
  {
    "tpope/vim-surround",
    event = "VeryLazy"
  },

  -- Handy bracket mappings: [q ]q [b ]b etc.
  { "tpope/vim-unimpaired", event = "VeryLazy" },

  -- Auto-insert "end" in Ruby-ish languages
  {
    "tpope/vim-endwise",
    ft = { "ruby", "lua", "vim", "sh", "zsh", }
  },
}
