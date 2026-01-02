-- Set up lazy.nvim as the nvim package manager
-- it loads the plugin specs in plugins/ lazily
require("lazy_setup")

-- Core config
require("options")
require("keymaps")

require("lsp")
require("notes").setup()
