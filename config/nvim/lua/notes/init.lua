--- Public entrypoint for notes. Call require("notes").setup() once.
local api = require("notes.notes")

local M = {}

--- Setup commands and keymaps for the notes module.
--- @param opts table|nil { keys = true|false, commands = true|false }
function M.setup(opts)
  opts = opts or {}
  local with_keys = opts.keys ~= false
  local with_cmds = opts.commands ~= false

  if with_cmds then
    vim.api.nvim_create_user_command("Zet", function(o)
      api.zet(o.fargs)
    end, { nargs = "*" })

    vim.api.nvim_create_user_command("Notes", function(o)
      api.search(o.args)
    end, { nargs = "*" })
  end

  if with_keys then
    vim.keymap.set("n", "<Leader>ns", function() api.search("") end, { desc = "Notes: search" })
    vim.keymap.set("n", "<Leader>nz", function() vim.fn.feedkeys(":Zet ", "n") end, { desc = "Notes: new zettel" })
  end
end

-- Re-export API (optional convenience)
M.open_index = api.open_index
M.zet = api.zet
M.search = api.search
M.insert_note_link = api.insert_note_link

return M
