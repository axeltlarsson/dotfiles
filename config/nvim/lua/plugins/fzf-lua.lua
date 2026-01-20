return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "FzfLua" },
    lazy = false,
    keys = {
      { "<Leader><Space>", function() require("fzf-lua").files() end,                 desc = "Find files" },
      { "<Leader>r",       function() require("fzf-lua").live_grep() end,             desc = "Live grep" },
      { "<Leader>b",       function() require("fzf-lua").buffers() end,               desc = "Buffer" },
      { "<Leader>C",       function() require("fzf-lua").git_commits() end,           desc = "Git commits" },
      { "<Leader>R",       function() require("fzf-lua").resume() end,                desc = "Resume" },

      -- LSP keymaps (gd, gr, gI, <Leader>c are in lsp.lua with nowait)
      { "<Leader>ld",      function() require("fzf-lua").diagnostics_document() end,  desc = "Diagnostics (buffer)" },
      { "<Leader>lD",      function() require("fzf-lua").diagnostics_workspace() end, desc = "Diagnostics (workspace)" },
    },
    opts = {
      files = {
        cmd = "fd --type f | sort -r",
      },
    },
    config = function(_, opts)
      local fzf = require("fzf-lua")
      fzf.setup(opts)
      fzf.register_ui_select()
    end,
  }
}
