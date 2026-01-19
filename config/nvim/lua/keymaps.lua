-- ============================================================================
-- Keymaps (global / core)
--
-- Put mappings here if they:
--   - Are core editor behavior, OR
--   - Call plugin *commands* (<cmd>Plugin ...<CR>), not Lua APIs
--
-- Mappings that call require("plugin") or should lazy-load a plugin
-- belong in the plugin spec (`keys = { ... }`).
-- ============================================================================

local keymap = vim.keymap

-- Clear search highlighting on Escape
keymap.set("n", "<Esc>", "<cmd>noh<CR><Esc>", { silent = true, desc = "Clear search highlight" })

-- Move lines up/down
keymap.set("n", "<C-j>", "<cmd>m .+1<CR>==", { silent = true, desc = "Move line down" })
keymap.set("n", "<C-k>", "<cmd>m .-2<CR>==", { silent = true, desc = "Move line up" })
keymap.set("v", "<C-j>", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move selection down" })
keymap.set("v", "<C-k>", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move selection up" })

-- Save/quit
keymap.set("n", "<Leader>w", "<cmd>w<CR>", { silent = true, desc = "Save" })
keymap.set("n", "<Leader>x", "<cmd>x<CR>", { silent = true, desc = "Save and quit" })
keymap.set("n", "<Leader>q", "<cmd>q<CR>", { silent = true, desc = "Quit" })
keymap.set("n", "<Leader>Q", "<cmd>q!<CR>", { silent = true, desc = "Force quit" })

-- Swedish layout helpers: ö -> [, ä -> ]
-- remap = true so that äd triggers ]d mappings, etc.
for _, mode in ipairs({ "n", "v", "o" }) do
  keymap.set(mode, "ö", "[", { remap = true })
  keymap.set(mode, "ä", "]", { remap = true })
end

-- Follow help links (tags)
keymap.set("n", "<Leader>g", "<C-]>", { desc = "Follow help tag" })

-- Copy current file:line to system clipboard
keymap.set("n", "<Leader>L", function()
  vim.fn.setreg("+", vim.fn.expand("%") .. ":" .. vim.fn.line("."))
end, { silent = true, desc = "Copy file:line to clipboard" })

-- Clipboard yanks/pastes
keymap.set({ "n", "v" }, "<Leader>y", '"+y', { desc = "Yank to clipboard" })
keymap.set("n", "<Leader>yy", '"+yy', { desc = "Yank line to clipboard" })
keymap.set("n", "<Leader>Y", '"+yg_', { desc = "Yank to EOL to clipboard" })
keymap.set({ "n", "v" }, "<Leader>p", '"+p', { desc = "Paste from clipboard" })
keymap.set("n", "<Leader>P", '"+P', { desc = "Paste before from clipboard" })
keymap.set("v", "<Leader>P", '"+P', { desc = "Paste before from clipboard" })

-- Sync clipboard yanks to tmux buffer (gives yank history via tmux buffer manager)
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    if vim.v.event.regname == "+" then
      local content = vim.fn.getreg("+")
      if content and content ~= "" then
        vim.fn.system({ "tmux", "set-buffer", "--", content })
      end
    end
  end,
})

-- Diagnostics
keymap.set("n", "gl", vim.diagnostic.open_float, { desc = "Line diagnostics" })
vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1 })
end, { desc = "Previous diagnostic" })

vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic" })
keymap.set("n", ",q", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })

-- Delete nvim 0.11 default LSP keymaps (we define our own in lsp.lua)
keymap.del('n', 'grn')
keymap.del('n', 'grr')
keymap.del('n', 'gri')
keymap.del('n', 'grt')
keymap.del('n', 'gra')
keymap.del('v', 'gra')
