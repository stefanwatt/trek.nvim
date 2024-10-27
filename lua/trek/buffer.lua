local utils = require("trek.utils")
local highlights = require("trek.highlights")

local M = {
  events = {},
}

---@param buf_id integer
function M.is_modified_buffer(buf_id)
  return true
  -- local data = M.opened_buffers[buf_id]
  -- return data ~= nil and data.n_modified and data.n_modified > 0
end

---@param buf_id integer
---@param path string
---@param children_ids integer[]
function M.compute_fs_diff(buf_id, path, children_ids)
  if not M.is_modified_buffer(buf_id) then
    return {}
  end

  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  local res, present_path_ids = {}, {}

  -- Process present file system entries
  local fs = require("trek.fs")
  for _, l in ipairs(lines) do
    local path_id = utils.match_line_path_id(l)
    local path_from = fs.path_index[path_id]

    -- Use whole line as name if no path id is detected
    local name_to = path_id ~= nil and l:sub(utils.match_line_offset(l)) or l

    -- Preserve trailing '/' to distinguish between creating file or directory
    local path_to = fs.get_child_path(path, name_to) .. (vim.endswith(name_to, "/") and "/" or "")

    -- Ignore blank lines and already synced entries (even several user-copied)
    if l:find("^%s*$") == nil and path_from ~= path_to then
      table.insert(res, { from = path_from, to = path_to })
    elseif path_id ~= nil then
      present_path_ids[path_id] = true
    end
  end

  -- Detect missing file system entries
  for _, ref_id in ipairs(children_ids) do
    if not present_path_ids[ref_id] then
      table.insert(res, { from = fs.path_index[ref_id], to = nil })
    end
  end

  return res
end

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
