local utils = require("trek.utils")
local M = {}

---@param entries trek.DirectoryEntry[]
---@return string[]
function M.get_dir_view(entries)
  return utils.map(
    entries,
    ---@param entry trek.DirectoryEntry
    function(entry)
      local icon = entry.fs_type == "directory" and "" or ""
      return icon .. " " .. entry.name
    end
  )
end

---@param path string
---@return string[]
function M.get_file_preview(path)
  return {}
end

return M
