vim.bo.shiftwidth = 2
vim.bo.tabstop = 2

vim.keymap.set("i", "<C-t>", function()
  require("notes").insert_note_link()
end, {
  buffer = true,
  desc = "Insert note link",
})

local function toggle_todo_line(line)
  if line:match("^(%s*)[%-%*] %[ %]") then
    return (line:gsub("(%[) (%])", "%1x%2", 1))
  elseif line:match("^(%s*)[%-%*] %[x%]") then
    return (line:gsub("(%[)x(%])", "%1 %2", 1))
  end
  return nil
end

vim.keymap.set("n", "<leader>tt", function()
  local new_line = toggle_todo_line(vim.api.nvim_get_current_line())
  if new_line then
    vim.api.nvim_set_current_line(new_line)
  end
end, {
  buffer = true,
  desc = "Toggle markdown todo",
})

vim.keymap.set("x", "<leader>tt", function()
  local start_line = vim.fn.line("v")
  local end_line = vim.api.nvim_win_get_cursor(0)[1]
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  for i, line in ipairs(lines) do
    lines[i] = toggle_todo_line(line) or line
  end
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
end, {
  buffer = true,
  desc = "Toggle markdown todos",
})
