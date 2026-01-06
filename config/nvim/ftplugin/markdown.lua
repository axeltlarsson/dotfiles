vim.keymap.set("i", "<C-t>", function()
  require("notes").insert_note_link()
end, {
  buffer = true,
  desc = "Insert note link",
})

-- Checkbox conceal
-- 
-- ×
-- 
-- - 󰡖 hej
-- - 󰝣 hej
-- 󰈜
vim.opt_local.conceallevel = 2
---@diagnostic disable-next-line: param-type-mismatch
vim.fn.matchadd('Conceal', '\\[\\ \\]', 0, -1, { conceal = '󰝣' })
---@diagnostic disable-next-line: param-type-mismatch
vim.fn.matchadd('Conceal', '\\[x\\]', 0, -1, { conceal = '󰡖' })
