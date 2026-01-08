return {
  {
    "rose-pine/neovim",
    lazy = false,
    priority = 1000,
    config = function()
      require("rose-pine").setup({
        highlight_groups = {
          -- Checked/unchecked todos (treesitter + render-markdown)
          ["@markup.list.checked"] = { fg = "rose" },
          ["@markup.list.unchecked"] = { fg = "rose" },
          ["RenderMarkdownChecked"] = { fg = "rose" },
          ["RenderMarkdownUnchecked"] = { fg = "rose" },
        },
      })
      vim.cmd.colorscheme("rose-pine")
    end,
  }
}
