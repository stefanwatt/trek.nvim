local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local utils = require("trek.utils")
local buffer = require("trek.buffer")
local lsp_helpers = require("trek.lsp.helpers")
---
---@alias trek.EntryType "file"|"directory"|"socket"|"link"|"fifo"
---@alias trek.FS_Action trek.CreateAction|trek.DeleteAction|trek.MoveAction|trek.CopyAction|trek.ChangeAction

---@class (exact) trek.CreateAction
---@field type "create"
---@field url string
---@field entry_type trek.EntryType
---@field link nil|string

---@class (exact) trek.DeleteAction
---@field type "delete"
---@field url string
---@field entry_type trek.EntryType

---@class (exact) trek.MoveAction
---@field type "move"
---@field entry_type trek.EntryType
---@field src_url string
---@field dest_url string

---@class (exact) trek.CopyAction
---@field type "copy"
---@field entry_type trek.EntryType
---@field src_url string
---@field dest_url string

---@class (exact) trek.ChangeAction
---@field type "change"
---@field entry_type trek.EntryType
---@field url string
---@field column string
---@field value any
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

---@param path string
---@param buf_id integer
function M.compute_fs_actions(path, buf_id)
  -- Compute differences
  local dir = M.get_dir_content(path)
  local children_ids = utils.map(dir.entries, function(entry)
    return entry.id
  end)
  local fs_diffs = {}
  local dir_fs_diff = M.compute_fs_diff(buf_id, path, children_ids)
  if #dir_fs_diff > 0 then
    vim.list_extend(fs_diffs, dir_fs_diff)
  end
  if #fs_diffs == 0 then
    return nil
  end

  -- Convert differences into actions
  local create, delete_map, rename, move, raw_copy = {}, {}, {}, {}, {}

  -- - Differentiate between create, delete, and copy
  for _, diff in ipairs(fs_diffs) do
    if diff.from == nil then
      table.insert(create, diff.to)
    elseif diff.to == nil then
      delete_map[diff.from] = true
    else
      table.insert(raw_copy, diff)
    end
  end

  -- - Possibly narrow down copy action into move or rename:
  --   `delete + copy` is `rename` if in same directory and `move` otherwise
  local copy = {}
  for _, diff in pairs(raw_copy) do
    if delete_map[diff.from] then
      if M.get_parent(diff.from) == M.get_parent(diff.to) then
        table.insert(rename, diff)
      else
        table.insert(move, diff)
      end

      -- NOTE: Can't use `delete` as array here in order for path to be moved
      -- or renamed only single time
      delete_map[diff.from] = nil
    else
      table.insert(copy, diff)
    end
  end

  return { create = create, delete = vim.tbl_keys(delete_map), copy = copy, rename = rename, move = move }
end

function M.apply_fs_actions(fs_actions)
  -- Copy first to allow later proper deleting
  for _, diff in ipairs(fs_actions.copy) do
    local ok, success = pcall(M.copy, diff.from, diff.to)
    local data = { action = "copy", from = diff.from, to = diff.to }
    if ok and success then
      utils.trigger_event("TrekActionCopy", data)
    end
  end

  for _, path in ipairs(fs_actions.create) do
    local ok, success = pcall(M.create, path)
    local data = { action = "create", to = M.normalize_path(path) }
    if ok and success then
      utils.trigger_event("TrekActionCreate", data)
    end
  end

  for _, diff in ipairs(fs_actions.move) do
    local data = { action = "move", from = diff.from, to = diff.to }
    local did_complete = lsp_helpers.will_perform_file_operations({
      {
        type = "move",
        entry_type = "file",
        src_url = data.from,
        dest_url = data.to,
      },
    })
    local ok, success = pcall(M.move, diff.from, diff.to)
    if ok and success then
      -- M.event_listeners.hide_explorer()
      vim.schedule(function()
        did_complete()
        utils.trigger_event("TrekActionMove", data)
      end)
    end
  end

  for _, diff in ipairs(fs_actions.rename) do
    local data = { action = "rename", from = diff.from, to = diff.to }
    local did_complete = lsp_helpers.will_perform_file_operations({
      {
        type = "move",
        entry_type = "file",
        src_url = data.from,
        dest_url = data.to,
      },
    })
    local ok, success = pcall(M.rename, diff.from, diff.to)
    if ok and success then
      -- M.event_listeners.hide_explorer()
      vim.schedule(function()
        did_complete()
        utils.trigger_event("TrekActionRename", data)
      end)
    end
  end

  -- Delete last to not lose anything too early (just in case)
  for _, path in ipairs(fs_actions.delete) do
    local config = require("trek.config").get_config()
    local ok, success = pcall(M.delete, path, config.options.permanent_delete)
    local data = { action = "delete", from = path }
    if ok and success then
      utils.trigger_event("TrekActionDelete", data)
    end
  end
end

---@param path string
function M.create(path)
  -- Don't override existing path
  if M.does_path_exist(path) then
    return M.warn_existing_path(path, "create")
  end

  -- Create parent directory allowing nested names
  vim.fn.mkdir(M.get_parent(path), "p")

  -- Create
  local fs_type = path:find("/$") == nil and "file" or "directory"
  if fs_type == "directory" then
    return vim.fn.mkdir(path) == 1
  else
    return vim.fn.writefile({}, path) == 0
  end
end

function M.copy(from, to)
  -- Don't override existing path
  if M.does_path_exist(to) then
    return M.warn_existing_path(from, "copy")
  end

  local from_type = M.get_type(from)
  if from_type == nil then
    return false
  end

  -- Allow copying inside non-existing directory
  vim.fn.mkdir(M.get_parent(to), "p")

  -- Copy file directly
  if from_type == "file" then
    return vim.loop.fs_copyfile(from, to)
  end

  -- Recursively copy a directory
  local fs_entries = M.get_dir_content(from)
  -- NOTE: Create directory *after* reading entries to allow copy inside itself
  vim.fn.mkdir(to)

  local success = true
  for _, entry in ipairs(fs_entries) do
    success = success and M.copy(entry.path, M.get_child_path(to, entry.name)) or success
  end

  return success
end

function M.delete(path, permanent_delete)
  if permanent_delete then
    return vim.fn.delete(path, "rf") == 0
  end

  -- Move to trash instead of permanent delete
  local trash_dir = M.get_child_path(vim.fn.stdpath("data"), "mini.files/trash")
  vim.fn.mkdir(trash_dir, "p")

  local trash_path = M.get_child_path(trash_dir, M.get_basename(path))

  -- Ensure that same basenames are replaced
  pcall(vim.fn.delete, trash_path, "rf")

  return vim.loop.fs_rename(path, trash_path)
end

function M.move(from, to)
  -- Don't override existing path
  if M.does_path_exist(to) then
    return M.warn_existing_path(from, "move or rename")
  end

  -- Move while allowing to create directory
  vim.fn.mkdir(M.get_parent(to), "p")
  local success = vim.loop.fs_rename(from, to)

  if not success then
    return success
  end

  -- Update path index to allow consecutive moves after undo (which also
  -- restores previous concealed path index)
  M.replace_path_in_index(from, to)

  -- TODO Rename in loaded buffers
  -- for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
  --   M.event_listeners.rename_loaded_buffer(buf_id, from, to)
  -- end

  return success
end

M.rename = M.move

function M.replace_path_in_index(from, to)
  local from_id, to_id = M.path_index[from], M.path_index[to]
  M.path_index[from_id], M.path_index[to] = to, from_id
  if to_id then
    M.path_index[to_id] = nil
  end
  -- Remove `from` from index assuming it doesn't exist anymore (no duplicates)
  M.path_index[from] = nil
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

-- ---@param buf_id integer
-- function M.is_modified_buffer(buf_id)
--   local data = M.opened_buffers[buf_id]
--   return data ~= nil and data.n_modified and data.n_modified > 0
-- end

---@param buf_id integer
---@param path string
---@param children_ids integer[]
function M.compute_fs_diff(buf_id, path, children_ids)
  -- if not M.is_modified_buffer(buf_id) then
  --   return {}
  -- end

  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  local res, present_path_ids = {}, {}

  -- Process present file system entries
  for _, l in ipairs(lines) do
    local path_id = utils.match_line_path_id(l)
    local path_from = M.path_index[path_id]

    -- Use whole line as name if no path id is detected
    local name_to = path_id ~= nil and l:sub(utils.match_line_offset(l)) or l

    -- Preserve trailing '/' to distinguish between creating file or directory
    local path_to = M.get_child_path(path, name_to) .. (vim.endswith(name_to, "/") and "/" or "")

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
      table.insert(res, { from = M.path_index[ref_id], to = nil })
    end
  end

  return res
end

-- ///////////////////////[UTILS]////////////////////////////
--
---@return trek.Directory | nil
function M.get_current_dir()
  return M.directory
end

---@param path string
---@return string
function M.normalize_path(path)
  return (path:gsub("/+", "/"):gsub("(.)/$", "%1"))
end

function M.full_path(path)
  return M.normalize_path(vim.fn.fnamemodify(path, ":p"))
end

function M.get_basename(path)
  return M.normalize_path(path):match("[^/]+$")
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
function M.does_path_exist(path)
  return vim.loop.fs_stat(path) ~= nil
end

---@param path string
function M.get_type(path)
  if not M.does_path_exist(path) then
    return nil
  end
  return vim.fn.isdirectory(path) == 1 and "directory" or "file"
end
function M.warn_existing_path(path, action)
  utils.notify(string.format("Can not %s %s. Target path already exists.", action, path), "WARN")
  return false
end

return M
