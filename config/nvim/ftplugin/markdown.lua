vim.keymap.set("i", "<C-t>", function()
  require("notes").insert_note_link()
end, {
  buffer = true,
  desc = "Insert note link",
})
