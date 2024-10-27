local utils = require("trek.utils")
local highlights = require("trek.highlights")

local M = {
  events = {},
}

local discarded_first = false
---@param buf_id integer
---@param cb function()
function M.on_lines_changed(buf_id, cb)
  discarded_first = false
  vim.api.nvim_buf_attach(buf_id, false, {
    on_lines = function(
      event,
      buf_handle,
      changedtick,
      first_line,
      last_line,
      last_line_updated,
      byte_count,
      deleted_codepoints,
      deleted_codeunits
    )
      -- table.insert(M.events, { ... })
      if not discarded_first then
        discarded_first = true
      else
        cb(first_line, last_line)
      end
    end,
  })
end

---@param buf_id integer
---@param path string
function M.buffer_update_file(buf_id, path)
  -- Determine if file is text. This is not 100% proof, but good enough.
  -- Source: https://github.com/sharkdp/content_inspector
  local fd = vim.loop.fs_open(path, "r", 1)
  if fd == nil then
    utils.error("file or directory not found: " .. path)
    return
  end
  local is_text = vim.loop.fs_read(fd, 1024):find("\0") == nil
  vim.loop.fs_close(fd)
  if not is_text then
    local user_config = require("trek.config").get_config()
    utils.set_buflines(buf_id, { "-Non-text-file" .. string.rep("-", user_config.windows.width_preview) })
    return
  end

  -- Compute lines. Limit number of read lines to work better on large files.
  local has_lines, read_res = pcall(vim.fn.readfile, path, "", vim.o.lines)
  -- - Make sure that lines don't contain '\n' (might happen in binary files).
  local lines = has_lines and vim.split(table.concat(read_res, "\n"), "\n") or {}

  -- Set lines
  utils.set_buflines(buf_id, lines)

  -- Add highlighting if reasonable (for performance or functionality reasons)
  if highlights.buffer_should_highlight(buf_id) then
    local ft = vim.filetype.match({ buf = buf_id, filename = path })
    if not ft then
      return
    end
    local has_lang, lang = pcall(vim.treesitter.language.get_lang, ft)
    local has_ts, _ = pcall(vim.treesitter.start, buf_id, has_lang and lang or ft)
    if not has_ts then
      vim.bo[buf_id].syntax = ft
    end
  end
end

return M
