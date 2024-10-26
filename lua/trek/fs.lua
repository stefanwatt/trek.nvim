---@class trek.Directory
---@field path string
---@field entries trek.DirectoryEntry[]

---@class trek.DirectoryEntry
---@field fs_type "file" | "directory"
---@field name string
---@field path string

---@class trek.Filesystem
---@field directory trek.Directory
local M = {}

---@param path string
---@return string
function M.normalize_path(path)
  return (path:gsub("/+", "/"):gsub("(.)/$", "%1"))
end

function M.full_path(path)
  return M.normalize_path(vim.fn.fnamemodify(path, ":p"))
end

---@param path string
---@return string | nil
function M.get_parent(path)
  path = M.full_path(path)
  if path == "/" then
    return nil
  end
  local res = M.normalize_path(path:match("^.*/"))
  return res
end

---@param dir string
---@param name string
---@return string
function M.get_child_path(dir, name)
  return M.normalize_path(string.format("%s/%s", dir, name))
end

---@param path string
---@return trek.Directory
function M.get_dir_content(path)
  local fs = vim.loop.fs_scandir(path)
  local entries = {}
  if not fs then
    return entries
  end
  local name, fs_type = vim.loop.fs_scandir_next(fs)
  while name do
    if fs_type == "file" or fs_type == "directory" then
      table.insert(entries, { fs_type = fs_type, name = name, path = M.get_child_path(path, name) })
    end
    name, fs_type = vim.loop.fs_scandir_next(fs)
  end
  return {
    path = path,
    entries = entries,
  }
end

---@return trek.Directory | nil
function M.get_current_dir()
  return M.directory
end

return M
