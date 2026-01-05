# Neovim init.vim → init.lua Migration Gap Analysis

**Generated**: 2026-01-03
**Status**: init.vim (448 lines) is NOT being loaded - Neovim prioritizes init.lua

---

## What's Currently Working (Lua Config)

### Loaded Plugins (via lazy.nvim)

 | Plugin                                 | Status   | Notes                                    |
 | --------                               | -------- | -------                                  |
 | rose-pine                              | Working  | Colorscheme                              |
 | nvim-treesitter                        | Working  | Highlight, indent, incremental selection |
 | nvim-lspconfig                         | Working  | 10 LSPs configured                       |
 | fzf-lua                                | Working  | Replaces fzf.vim                         |
 | lualine                                | Working  | Statusline                               |
 | vim-fugitive                           | Working  | Git                                      |
 | vim-surround/repeat/unimpaired/endwise | Working  | tpope suite                              |
 | lazydev                                | Working  | Lua dev support                          |
 | nvim-web-devicons                      | Working  | Icons                                    |

### Lua Modules
- `options.lua` - Editor settings, treesitter folding
- `keymaps.lua` - Core mappings with descriptions
- `lsp.lua` - LSP enable/config/keymaps
- `notes/` - Zettelkasten system (well-structured rewrite)

---

## Complete Gap Analysis

### Category 1: Core Editor Features (Missing)

| Feature | Old Plugin | Status | Modern Alternative | Notes |
|---------|-----------|--------|-------------------|-------|
| **Snippets** | UltiSnips | NOT LOADED | **LuaSnip** | Can load UltiSnips format snippets. You have 235+ HTML snippets in `~/.config/nvim/UltiSnips/` |
| **Git signs** | vim-gitgutter | NOT LOADED | **gitsigns.nvim** | Pure Lua, faster, more features (inline blame, hunk actions) |
| **Commenting** | nerdcommenter | NOT LOADED | **Comment.nvim** or **mini.comment** | Comment.nvim is most popular; mini.comment is simpler |
| **File browser** | fern.vim | NOT LOADED | **oil.nvim** (minimal) or **neo-tree** (feature-rich) | oil.nvim edits filesystem like a buffer - feels natural |

### Category 2: AI/Writing Features (Missing)

| Feature | Old Plugin | Status | Modern Alternative | Notes |
|---------|-----------|--------|-------------------|-------|
| **AI completion** | copilot.vim | NOT LOADED | **copilot.lua** + copilot-cmp | Native Lua, better integration. Original also works. |
| **Zen mode** | goyo.vim + limelight.vim | NOT LOADED | **zen-mode.nvim** + **twilight.nvim** | Both by folke. Twilight dims inactive code like limelight |
| **Regex UI** | nvim-regexplainer | NOT LOADED | Same plugin or **Hypersonic.nvim** | Hypersonic shows live regex matches in buffer |

### Category 3: Language/Syntax Features (Missing)

| Feature | Old Plugin | Status | Modern Alternative | Notes |
|---------|-----------|--------|-------------------|-------|
| **Markdown** | vim-markdown | NOT LOADED | **render-markdown.nvim** | Renders markdown in-buffer (checkboxes, tables, headers). Very nice. Or **markdown-preview.nvim** for browser preview |
| **EditorConfig** | editorconfig-vim | NOT LOADED | **Built-in** (Neovim 0.9+) | Just add `vim.g.editorconfig = true` to options.lua |
| **JavaScript/JSX** | vim-javascript + vim-jsx-pretty | NOT LOADED | **Treesitter** | Already covered - TS handles JS/JSX syntax |
| **Polyglot** | vim-polyglot | NOT LOADED | **Treesitter** | Not needed - TS handles multi-language syntax |

### Category 4: Linting/Formatting (Missing)

| Feature | Old Plugin | Status | Modern Alternative | Notes |
|---------|-----------|--------|-------------------|-------|
| **Format on save** | ALE | NOT LOADED | **conform.nvim** or **LSP** | You have LSP formatting (`<Leader>f`). ALE covered: pgformatter (SQL), jq (JSON), ormolu (Haskell), pandoc (Markdown), rubyfmt (Ruby), gofmt (Go), shfmt (Shell) |
| **Extra linting** | ALE | NOT LOADED | **nvim-lint** | For linters not in LSP. ALE had: sqlint, shellcheck, rubocop |

### Category 5: Utilities (Missing)

| Feature | Old Plugin | Status | Modern Alternative | Notes |
|---------|-----------|--------|-------------------|-------|
| **Emoji picker** | unicodemoji | NOT LOADED | **icon-picker.nvim** or same | `<Leader>u` keymap exists but does nothing |
| **Tabular align** | tabular | NOT LOADED | **mini.align** | Similar functionality, pure Lua |
| **Pencil (writing)** | vim-pencil | NOT LOADED | **wrapping.nvim** or built-in | vim-pencil did soft wrap, etc. for prose |

### Category 6: Missing Config/Autocommands

| Setting | Old Location | Status | How to Migrate |
|---------|-------------|--------|----------------|
| `.roc` filetype | init.vim:334 | NOT APPLIED | Add to options.lua: `vim.filetype.add({ extension = { roc = "roc" }})` |
| `.typ` filetype | init.vim:336 | NOT APPLIED | Add to options.lua: `vim.filetype.add({ extension = { typ = "typst" }})` |
| `keywordprg=:Rg` | init.vim:98 | NOT SET | Add: `vim.o.keywordprg = ":Rg"` (K to search word) |
| NBSP error highlight | init.vim:266-274 | NOT APPLIED | Can add as autocmd in Lua |
| Ruby keywordprg | init.vim:102 | NOT APPLIED | ftplugin/ruby.lua |

---

## ALE Replacement Analysis

Your init.vim ALE config covered:

**Formatters (ale_fixers):**
- SQL: pgformatter → Use conform.nvim with pg_format
- JSON: jq → Use conform.nvim
- Haskell: ormolu → LSP (hls) or conform.nvim
- JavaScript: eslint → LSP (eslint-lsp) handles this
- Markdown: pandoc → conform.nvim
- Ruby: rubyfmt → conform.nvim (your LSP is ruby_lsp with formatting disabled, so you need this)
- Go: gofmt → LSP (gopls) includes gofmt
- Shell: shfmt → conform.nvim

**Linters (ale_linters):**
- SQL: sqlint → nvim-lint
- JavaScript: prettier+eslint → LSP handles
- Ruby: rubocop → ruby_lsp includes rubocop
- Shell: shellcheck → nvim-lint or LSP (bashls)

**Recommendation**: Add conform.nvim for: pgformatter, jq, pandoc, rubyfmt, shfmt. These aren't covered by your LSP setup.

---

## Issues in Current Lua Config

### 1. Duplicate Keymap (notes/init.lua:25-26)
```lua
vim.keymap.set("n", "<Leader>nz", function() vim.cmd("Zet ") end, ...)
vim.keymap.set("n", "<Leader>nz", function() vim.fn.feedkeys(":Zet ", "n") end, ...)
```
Second overwrites first. Only one needed.

### 2. Missing Notes Index Keymap
`<Leader>ni` for opening `$NOTES_DIR/index.md` not migrated.

### 3. Orphan Keymap
`<Leader>u` maps to `:Unicodemoji<CR>` but plugin isn't loaded.

### 4. Missing Filetypes
`.roc` and `.typ` file associations not migrated to Lua.

---

## Modern Alternatives Summary

### Tier 1: Highly Recommended (Popular, Well-Maintained)

| Need | Plugin | Why |
|------|--------|-----|
| Git signs | **gitsigns.nvim** | Pure Lua, inline blame, hunk stage/reset, fast |
| Commenting | **Comment.nvim** | Treesitter-aware, 2k+ stars, gc/gcc motions |
| Snippets | **LuaSnip** | Fastest, loads UltiSnips format, nvim-cmp integration |
| File browser | **oil.nvim** | Edit filesystem like a buffer. Minimalist, intuitive |
| Formatting | **conform.nvim** | By LazyVim author, format on save, async, per-filetype |
| Markdown | **render-markdown.nvim** | In-buffer rendering: checkboxes, tables, code blocks |

### Tier 2: Modern but Optional

| Need | Plugin | Why |
|------|--------|-----|
| Copilot | **copilot.lua** | Pure Lua copilot, works with nvim-cmp |
| Zen mode | **zen-mode.nvim** | By folke, with twilight.nvim for dimming |
| Linting | **nvim-lint** | For linters without LSP support |
| Align | **mini.align** | Part of mini.nvim ecosystem |

### Tier 3: Can Skip (Built-in or TS Handles)

| Old Plugin | Skip Because |
|------------|--------------|
| editorconfig-vim | Neovim 0.9+ has builtin |
| vim-polyglot | Treesitter handles syntax |
| vim-javascript/jsx-pretty | Treesitter handles JS/JSX |
| bats.vim | Probably niche |

---

## Your Lua Setup: Pros and Cons

### Pros
- Clean module separation (options/keymaps/lsp separate)
- Proper lazy loading via cmd/keys/ft triggers
- Modern fzf-lua replaces legacy fzf.vim
- Treesitter-based folding with foldlevel=99
- XDG paths (`stdpath("state")`) instead of `~/.vim`
- Keymap descriptions ready for which-key
- Notes module is proper Lua, not just vim→lua translation

### Cons / Areas to Improve
- init.vim still exists (confusing)
- Several keymaps reference plugins that aren't loaded
- No autocompletion (nvim-cmp) setup
- No which-key for keymap discovery
- Notes module has duplicate keymap bug
- Missing LSP keymaps: workspace folders (`<Leader>va/vr/vl`)

### Missing Keymaps from VimL
- `<Leader>B` - BCommits (buffer commits)
- `,e` - diagnostic float (you have `gl` instead)
- Insert-mode fzf completion (`<C-x><C-k>`, `<C-x><C-f>`)
- Fern file drawer toggle (`<Leader>d`, `<Leader>F`)
- ALE fix command (`<Leader>l`)

---

## Files Reference

| File | Lines | Purpose |
|------|-------|---------|
| `init.lua` | 10 | Entry point |
| `init.vim` | 448 | **LEGACY - NOT LOADED** |
| `lua/options.lua` | 61 | Editor settings |
| `lua/keymaps.lua` | 65 | Global keybindings |
| `lua/lsp.lua` | 83 | LSP configuration |
| `lua/lazy_setup.lua` | 30 | Plugin manager bootstrap |
| `lua/notes/init.lua` | 36 | Notes public API |
| `lua/notes/notes.lua` | 202 | Notes implementation |
| `lua/plugins/*.lua` | 7 files | Plugin specs |
