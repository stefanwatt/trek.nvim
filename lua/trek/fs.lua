---@class trek.Directory
---@field path string
---@field entries trek.DirectoryEntry[]

---@class trek.DirectoryEntry
---@field id integer
---@field fs_type "file" | "directory"
---@field name string
---@field path string

---@class trek.Filesystem
---@field directory trek.Directory
---@field path_index table
local M = {
  path_index = {},
}

---@param path string
---@return string
function M.normalize_path(path)
  return (path:gsub("/+", "/"):gsub("(.)/$", "%1"))
end

function M.full_path(path)
  return M.normalize_path(vim.fn.fnamemodify(path, ":p"))
end

---@param path string
---@return string
function M.get_directory_of_path(path)
  local full_path = M.full_path(path)
  local stat = vim.loop.fs_stat(full_path)

  if stat and stat.type == "directory" then
    return full_path
  else
    return M.get_parent(full_path) or ""
  end
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
      local child_path = M.get_child_path(path, name)
      table.insert(entries, {
        fs_type = fs_type,
        name = name,
        path = child_path,
        id = M.add_path_to_index(child_path),
      })
    end
    name, fs_type = vim.loop.fs_scandir_next(fs)
  end
  return {
    path = path,
    entries = entries,
  }
end

---@param path string
---@return integer 
function M.add_path_to_index(path)
  local cur_id = M.path_index[path]
  if cur_id ~= nil then
    return cur_id
  end

  local new_id = #M.path_index + 1
  M.path_index[new_id] = path
  M.path_index[path] = new_id

  return new_id
end
---@return trek.Directory | nil
function M.get_current_dir()
  return M.directory
end

return M
