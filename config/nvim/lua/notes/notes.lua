-- My zettelkasten-inspired note-taking system
-- - NOTES_DIR from env (fallback ~/notes)
-- - `zet` creates timestamped note with optional sluge + inserts "# Title"
-- - `notes_search` searches notes wifh fzf-lua (no args => <cword>)
-- - insert_note_link picks a note with fzf-lua and inserts a relative Markdown link
local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "notes" })
end

local function notes_dir()
  local dir = vim.env.NOTES_DIR
  if not dir or dir == "" then
    dir = vim.fn.expand("~/notes")
  end
  dir = vim.fs.normalize(vim.fn.fnamemodify(dir, ":p"))
  return dir
end

local function ensure_dir(dir)
  local ok = vim.fn.isdirectory(dir) == 1
  if ok then return true end
  local created = vim.fn.makedir(dir, "p")
  return created == 1
end

local function slugify(words)
  if not words or #words == 0 then return "" end
  local s = table.concat(words, " ")
  s = s:lower()

  -- Normalize whitespace/punctuation into separators.
  s = s:gsub("[%c]", " ")
  s = s:gsub("[`'\"“”‘’]", "")
  s = s:gsub("[^%w%s%-_]", " ") -- keep alnum, space, - _
  s = s:gsub("[%s_]+", "-")     -- spaces/_ -> -
  s = s:gsub("%-+", "-")        -- collapse
  s = s:gsub("^%-+", ""):gsub("%-+$", "")

  return s
end

local function title_from_words(words)
  if not words or #words == 0 then return nil end
  return table.concat(words, " ")
end

local function strip_timestamp_prefix(stem)
  -- Format: YYYYmmddHHMM-<slug>.md
  -- Also tolerate any leading digits + optional '-'
  stem = stem:gsub("^%d%d%d%d%d%d%d%d%d%d%d%d%-?", "") -- 12-digit timestamp
  stem = stem:gsub("^%d+%-", "")
  return stem
end

local function label_from_path(path)
  local stem = vim.fn.fnamemodify(path, ":t:r") -- filename without extension
  stem = strip_timestamp_prefix(stem)
  stem = stem:gsub("_", " "):gsub("%-", " ")
  stem = stem:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return stem ~= "" and stem or vim.fn.fnamemodify(path, ":t:r")
end

local function rel_link(from_file, to_file)
  local from_dir = vim.fs.normalize(vim.fn.fnamemodify(from_file or "", ":p:h"))
  local to_abs = vim.fs.normalize(vim.fn.fnamemodify(to_file, ":p"))
  local to_dir = vim.fs.normalize(vim.fn.fnamemodify(to_file, ":p:h"))
  local to_name = vim.fn.fnamemodify(to_file, ":t")

  -- Same directory: just ./filename
  if from_dir == to_dir then
    return "./" .. to_name
  end

  -- Different directories: compute relative path
  local rel = vim.fs.relpath(to_abs, from_dir)
  if rel then
    return "./" .. rel
  end

  -- Fallback to absolute
  return to_abs
end

local function buf_is_empty(bufnr)
  if vim.api.nvim_buf_line_count(bufnr) ~= 1 then return false end
  local l = (vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or "")
  return l == ""
end

local function insert_text_at_cursor(text)
  local bufnr = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))

  -- row is 1-based; buf_set_text uses 0-based.
  vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { text })
  vim.api.nvim_win_set_cursor(0, { row, col + #text })
end

--- Create and open a new note.
--- @param words string[]|nil title words; slug is derived from these
function M.zet(words)
  local dir = notes_dir()
  if not ensure_dir(dir) then
    notify(("Unable to crate notes directory: %s"):format(dir), vim.log.levels.ERROR)
    return
  end

  local ts = os.date("%Y%m%d%H%M")
  local slug = slugify(words or {})
  local sep = (slug ~= "" and "-") or ""
  local path = vim.fs.joinpath(dir, ts .. sep .. slug .. ".md")

  vim.cmd.edit(vim.fn.fnameescape(path))

  local title = title_from_words(words or {})
  if title and buf_is_empty(0) then
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { "# " .. title, "" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
  end
end

--- Search notes using fzf-lua live_grep
--- query:
---   nil → seed with <cword>
---   ""  → start empty
---   "x" → start "x"
--- @param query string|nil
function M.search(query)
  local dir = notes_dir()
  if not ensure_dir(dir) then
    notify(("Unable to create notes directory: %s"):format(dir), vim.log.levels.ERROR)
    return
  end

  local seed = query
  if seed == nil then
    seed = vim.fn.expand("<cword>")
  end

  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    notify("fzf-lua is not available", vim.log.levels.ERROR)
    return
  end

  fzf.live_grep({
    cwd = dir,
    search = (seed ~= "" and seed or nil),
    prompt = "Notes> "
  })
end

--- Pick a note file and insert a Markdown link at cursor
--- Label strips timestamp prefix and normalizes '_' to spaces
function M.insert_note_link()
  local dir = notes_dir()
  if not ensure_dir(dir) then
    notify(("Unable to create notes directory: %s"):format(dir), vim.log.level.ERROR)
    return
  end

  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    notify("fzf-lua is not available", vim.log.levels.ERROR)
    return
  end

  fzf.files({
    cwd = dir,
    prompt = "Link note> ",
    actions = {
      ["default"] = function(selected)
        local entry = selected and selected[1]
        if not entry or entry == "" then return end

        entry = entry:gsub("\27%[[0-9;]*m", "") -- strip ANSI codes
        local rel = entry:match("(%S+)$")
        if not rel or rel == "" then return end

        -- Extract icon prefix for label, strip from path
        local icon = rel:match("^([\128-\255]+)") or ""
        rel = rel:gsub("^[\128-\255]+", "")

        local target = vim.fs.joinpath(dir, rel)

        local label = icon .. label_from_path(target)
        local link = "./" .. rel
        -- Quote path if it contains spaces
        if link:find(" ") then
          link = "<" .. link .. ">"
        end
        local md = ("[%s](%s)"):format(label, link)

        insert_text_at_cursor(md)
      end,
    },
  })
end

return M
