return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",

    config = function()
      -- N.B! CC needs to be unset (not set to clang as in nix shells)
      vim.env.CC = ""
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "bash",
          "c",
          "comment",
          "css",
          "elm",
          "go",
          "haskell",
          "html",
          "javascript",
          "json",
          "lua",
          "nix",
          "python",
          "regex",
          "roc",
          "ruby",
          "sql",
          "typst",
          "vim",
          "vimdoc",
          "yaml",
        },
        highlight = {
          enable = true
        },
        indent = {
          enable = true
        },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = 'gnn',
            node_incremental = 'grn',
            scope_incremental = 'grc',
            node_decremental = 'grm',
          }
        }
      })
    end
  }
}
