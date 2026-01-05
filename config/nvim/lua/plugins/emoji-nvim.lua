return {
  {
    "allaman/emoji.nvim",
    ft = "markdown",
    cmd = { "Emoji" },
    keys = {
      { "<leader>u", function() require("emoji").insert() end, desc = "Emoji picker" },
    },
    dependencies = {
      -- util for handling paths
      "nvim-lua/plenary.nvim",
      -- optional for fzf-lua integration via vim.ui.select
      "ibhagwan/fzf-lua",
    },
    config = function(_, opts)
      require("emoji").setup(opts)
    end,
  }
}
