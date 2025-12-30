return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "FzfLua" },
    keys = {
      { "<Leader><Space>", function() require("fzf-lua").files() end,                 desc = "Find files" },
      { "<Leader>r",       function() require("fzf-lua").live_grep() end,             desc = "Live grep" },
      { "<Leader>b",       function() require("fzf-lua").buffers() end,               desc = "Buffer" },
      { "<Leader>C",       function() require("fzf-lua").git_commits() end,           desc = "Git commits" },
      { "<Leader>R",       function() require("fzf-lua").resume() end,                desc = "Resume" },

      -- LSP keymaps
      { "gd",              function() require("fzf-lua").lsp_definitions() end,       desc = "LSP: Definitions" },
      { "gr",              function() require("fzf-lua").lsp_references() end,        desc = "LSP: References" },
      { "gi",              function() require("fzf-lua").lsp_implementations() end,   desc = "LSP: Implementations" },
      { "<Leader>ca",      function() require("fzf-lua").lsp_code_actions() end,      mode = { "n", "v" },             desc = "LSP: Code actions" },
      { "<Leader>ld",      function() require("fzf-lua").diagnostics_document() end,  desc = "Diagnostics (buffer)" },
      { "<Leader>lD",      function() require("fzf-lua").diagnostics_workspace() end, desc = "Diagnostics (workspace)" },
    },
    opts = {}
  }
}
