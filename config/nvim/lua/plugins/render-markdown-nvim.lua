return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    ---@module 'render-markdown'
    opts = {},
    config = function()
      require("render-markdown").setup(
        {
          heading = {
            width = "block",
            right_pad = 1,
          },
          code = {
            width = "block",
            right_pad = 1,
          },
          checkbox = {
            unchecked = {
              -- Replaces '[ ]' of 'task_list_marker_unchecked'.
              icon = '󰝣 ',
              -- Highlight for the unchecked icon.
              highlight = 'RenderMarkdownUnchecked',
              -- Highlight for item associated with unchecked checkbox.
              scope_highlight = nil,
            },
            checked = {
              -- Replaces '[x]' of 'task_list_marker_checked'.
              icon = '󰡖 ',
              -- Highlight for the checked icon.
              highlight = 'RenderMarkdownChecked',
              -- Highlight for item associated with checked checkbox.
              scope_highlight = nil,
            },
          }
        })
    end,
  }
}
