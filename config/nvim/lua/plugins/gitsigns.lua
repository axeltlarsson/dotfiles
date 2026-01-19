return {
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",
    opts = {
      signs = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "▁" },
        topdelete    = { text = "▔" },
        changedelete = { text = "▎" },
      },
      preview_config = {
        border = "rounded",
      },
      diff_opts = {
        internal = true,
      },
    },
    keys = {
      { "]c", function() require("gitsigns").nav_hunk("next") end, desc = "Next hunk" },
      { "[c", function() require("gitsigns").nav_hunk("prev") end, desc = "Prev hunk" },
      { "<Leader>hs", function() require("gitsigns").stage_hunk() end, desc = "Stage/unstage hunk", mode = { "n", "v" } },
      { "<Leader>hr", function() require("gitsigns").reset_hunk() end, desc = "Reset hunk", mode = { "n", "v" } },
      { "<Leader>hS", function() require("gitsigns").stage_buffer() end, desc = "Stage buffer" },
      { "<Leader>hR", function() require("gitsigns").reset_buffer() end, desc = "Reset buffer" },
      { "<Leader>hp", function() require("gitsigns").preview_hunk_inline() end, desc = "Preview hunk" },
      { "<Leader>hb", function() require("gitsigns").blame_line({ full = true }) end, desc = "Blame line" },
      { "<Leader>hd", function() require("gitsigns").diffthis() end, desc = "Diff this" },
    },
  },
}
