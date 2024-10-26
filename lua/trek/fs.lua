---@class trek.Directory
---@field path string
---@field entries trek.DirectoryEntry[]

---@class trek.DirectoryEntry
---@field fs_type "file" | "directory"
---@field name string
---@field path string

local M = {}


function M.normalize_path(path) return (path:gsub('/+', '/'):gsub('(.)/$', '%1')) end

function M.child_path(dir, name) return M.normalize_path(string.format('%s/%s', dir, name)) end

---@param path string
---@return trek.Directory
function M.get_dir_content(path)
  local fs = vim.loop.fs_scandir(path)
  local entries = {}
  if not fs then return entries end
  local name, fs_type = vim.loop.fs_scandir_next(fs)
  while name do
    if not (fs_type == 'file' or fs_type == 'directory') then print("neither dir nor file") end
    table.insert(entries, { fs_type = fs_type, name = name, path = M.child_path(path, name) })
    name, fs_type = vim.loop.fs_scandir_next(fs)
  end
  return {
    path = path,
    entries = entries
  }
end

return M
