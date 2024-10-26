local has_devicons, devicons = pcall(require, "nvim-web-devicons")
---
---@class trek.Directory
---@field path string
---@field entries trek.DirectoryEntry[]

---@class trek.DirectoryEntry
---@field id integer
---@field fs_type "file" | "directory"
---@field name string
---@field path string
---@field icon string | nil
---@field icon_hl_group string | nil

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
      local entry = {
        fs_type = fs_type,
        name = name,
        path = child_path,
        id = M.add_path_to_index(child_path),
      }
      if fs_type == "file" then
        local icon, hl = devicons.get_icon(name, nil, { default = false })
        entry.icon = icon
        entry.icon_hl_group = hl
      end
      table.insert(entries, entry)
    end
    name, fs_type = vim.loop.fs_scandir_next(fs)
  end
  return {
    path = path,
    entries = M.sort_entries(entries),
  }
end

---@param entries trek.DirectoryEntry[]
---@return trek.DirectoryEntry[]
function M.sort_entries(entries)
  local directories = {}
  local files = {}
  for _, entry in ipairs(entries) do
    if entry.fs_type == "directory" then
      table.insert(directories, entry)
    else
      table.insert(files, entry)
    end
  end
  table.sort(directories, function(a, b)
    return string.lower(a.name) < string.lower(b.name)
  end)
  table.sort(files, function(a, b)
    return string.lower(a.name) < string.lower(b.name)
  end)
  local sorted_entries = {}
  for _, dir in ipairs(directories) do
    table.insert(sorted_entries, dir)
  end
  for _, file in ipairs(files) do
    table.insert(sorted_entries, file)
  end
  return sorted_entries
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
