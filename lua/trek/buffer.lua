local utils = require("trek.utils")

local M = {}

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

return M
