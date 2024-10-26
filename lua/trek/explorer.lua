local utils = require("trek.utils")
local window = require("trek.window")
local fs = require("trek.fs")

local M = {}

---@param directory trek.Directory
function M.open(directory)
  local current_window = window.open()
  local lines = M.mapBufLines(directory.entries)
  vim.api.nvim_buf_set_lines(current_window.center_buf_id, 0, -1, false, lines)
  local parent_path = fs.get_parent(directory.path)
  if parent_path ~= nil then
    local parent_dir = fs.get_dir_content(parent_path)
    lines = M.mapBufLines(parent_dir.entries)
    vim.api.nvim_buf_set_lines(current_window.left_buf_id, 0, -1, false, lines)
  end
end

---@param entries trek.DirectoryEntry[]
---@return lines string[]
function M.mapBufLines(entries)
  return utils.map(
    entries,
    ---@param entry trek.DirectoryEntry
    function(entry)
      local icon = entry.fs_type == "directory" and "" or ""
      return icon .. " " .. entry.name
    end
  )
end

return M
