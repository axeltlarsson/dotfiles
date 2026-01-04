return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      vim.env.CC = ""

      local parsers = {
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
        "markdown",
        "markdown_inline",
        "nix",
        "python",
        "regex",
        "roc",
        "ruby",
        "sql",
        "toml",
        "typst",
        "vim",
        "vimdoc",
        "yaml",
        "zsh",
      }
      require("nvim-treesitter").install(parsers)

      vim.api.nvim_create_autocmd('FileType', {
        pattern = parsers,
        callback = function()
          vim.treesitter.start()
        end,
      })
    end,
  },
}
