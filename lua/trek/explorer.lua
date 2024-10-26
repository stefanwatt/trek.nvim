local utils = require("trek.utils")

local M = {}

---@param directory trek.Directory
function M.open(directory)
  vim.cmd("tabnew")
  M.tab_id = vim.api.nvim_get_current_tabpage()
  local lines = M.mapBufLines(directory.entries)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

---@param entries trek.DirectoryEntry[]
---@return lines string[]
function M.mapBufLines(entries)
  return utils.map(entries,
    ---@param entry trek.DirectoryEntry
    function(entry)
      local icon = entry.fs_type == "directory" and "" or ""
      return icon .. " " .. entry.name
    end
  )
end

return M
