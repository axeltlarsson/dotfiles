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
        "tmux",
        "toml",
        "typst",
        "vim",
        "vimdoc",
        "yaml",
        "zsh",
      }
      require("nvim-treesitter").install(parsers)

      -- Custom predicate: matches strings starting with a SQL keyword (case-insensitive)
      local sql_keywords = { "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "WITH", "MERGE", "PRAGMA" }
      vim.treesitter.query.add_predicate("sql-keyword?", function(match, _, source, pred)
        local nodes = match[pred[2]]
        if not nodes or #nodes == 0 then return true end
        for _, node in ipairs(nodes) do
          local text = vim.treesitter.get_node_text(node, source)
          local first_word = text:match("^%s*(%a+)")
          if first_word then
            first_word = first_word:upper()
            for _, kw in ipairs(sql_keywords) do
              if first_word == kw then return true end
            end
          end
        end
        return false
      end, { force = true })

      vim.api.nvim_create_autocmd('FileType', {
        pattern = parsers,
        callback = function()
          vim.treesitter.start()
        end,
      })
    end,
  },
}
