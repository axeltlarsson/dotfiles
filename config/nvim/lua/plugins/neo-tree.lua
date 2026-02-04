return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons", -- optional, but recommended
    },
    lazy = false,                    -- neo-tree will lazily load itself
    keys = {
      { "<leader>d", "<cmd>Neotree reveal<cr>", desc = "Reveal file in Neo-tree" },
    },
    config = function(_, _)
      require("neo-tree").setup({
        close_if_last_window = true,
        filesystem = {
          follow_current_file = { enabled = true },
        },
        window = {
          mappings = {
            ["P"] = {
              "toggle_preview",
              config = {
                use_float = true,
              },
            },
            ["l"] = "open",
            ["h"] = "close_node",
            ["[c"] = "prev_git_modified",
            ["]c"] = "next_git_modified",
          },
        }
      })
    end,
  }
}
