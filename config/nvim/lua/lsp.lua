local lsp = vim.lsp

lsp.enable({
  'bashls',
  'elmls',
  'gopls',
  'lua_ls',
  'nil_ls',
  'roc_ls',
  'ruby_lsp',
  'ruff',
  'tinymist',
  'ty',
})

lsp.config('ruby_lsp', {
  init_options = {
    formatting = false, -- disable formatting as I use rubyfmt
    linters = { 'standard' },
  }
})
lsp.config('nil_ls', {
  settings = {
    ['nil'] = {
      formatting = {
        command = { "nixfmt" },
      },
    },
  },
})
lsp.config('tinymist', {
  settings = {
    exportPdf = "onType",
    formatterMode = "typstyle",
  },
})

lsp.config('lua_ls', {
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
    },
  }
})


-- Keymaps

-- when no LSP K → diagnostics
vim.keymap.set('n', 'K', vim.diagnostic.open_float, {
  desc = "Diagnostics"
})

vim.diagnostic.config({
  virtual_text = true
})

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
-- See plugings/fzf-lua.lua for some keymaps that uses fzf listings
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Disable LSP semantic tokens: theme is better tuned for treesitter
    -- highlighting, and it's faster (no delayed color shift on first edit)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client then
      client.server_capabilities.semanticTokensProvider = nil
    end

    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    -- rn in Normal mode maps to vim.lsp.buf.rename()
    -- grr in Normal mode maps to vim.lsp.buf.references()
    -- gri in Normal mode maps to vim.lsp.buf.implementation()
    -- gO in Normal mode maps to vim.lsp.buf.document_symbol() (this is analogous to the gO mappings in help buffers and :Man page buffers to show a “table of contents”)
    -- gra in Normal and Visual mode maps to vim.lsp.buf.code_action()
    -- CTRL-S in Insert and Select mode maps to vim.lsp.buf.signature_help()
    -- [d and ]d move between diagnostics in the current buffer ([D jumps to the first diagnostic, ]D jumps to the
    -- When LSP K → LSP hover
    vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = ev.buf, desc = "LSP: Hover" })

    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { buffer = ev.buf, desc = "LSP: Declaration" })
    vim.keymap.set('n', 'gK', vim.lsp.buf.signature_help, { buffer = ev.buf, desc = "LSP: Signature help" })
    vim.keymap.set('n', '<Leader>D', vim.lsp.buf.type_definition, { buffer = ev.buf, desc = "LSP: Type definition" })
    vim.keymap.set('n', '<Leader>m', vim.lsp.buf.rename, { buffer = ev.buf, desc = "LSP: Rename" })
    vim.keymap.set('n', '<Leader>f', function()
      vim.lsp.buf.format { async = true }
    end, { buffer = ev.buf, desc = "LSP: Format" })
  end,
})
