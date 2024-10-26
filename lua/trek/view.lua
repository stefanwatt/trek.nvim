local utils = require("trek.utils")
local M = {}

---@param entries trek.DirectoryEntry[]
---@return string[]
function M.get_dir_view(entries)
  return utils.map(
    entries,
    ---@param entry trek.DirectoryEntry
    function(entry)
      local icon = M.get_icon(entry)
      return icon .. " " .. entry.name
    end
  )
end

---@param path string
---@return string[]
function M.get_file_preview(path)
  return {}
end

---@param entry trek.DirectoryEntry
---@return string
function M.get_icon(entry)
  if entry.fs_type == "directory" then
    return " "
  end
  local has_devicons, devicons = pcall(require, "nvim-web-devicons")
  if not has_devicons then
    return " "
  end

  local icon, hl = devicons.get_icon(entry.name, nil, { default = false })
  return (icon or "") .. " "
end

return M
