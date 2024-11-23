local M = {
  block_event_trigger = {},
  is_windows = false,
}

---@generic T
---@param list T[]
---@param cb function(value: `T`): `T`
function M.map(list, cb)
  local result = {}
  for _, value in ipairs(list) do
    table.insert(result, cb(value))
  end
  return result
end

---@generic T
---@param list T[]
---@param predicate function(value: T): boolean
---@return T[]
function M.filter(list, predicate)
  local result = {}
  for _, value in ipairs(list) do
    if predicate(value) then
      table.insert(result, value)
    end
  end
  return result
end

---@generic T
---@param list T[]
---@param cb function(value: `T`): boolean
---@return T | nil
function M.find(list, cb)
  for _, value in ipairs(list) do
    if cb(value) then
      return value
    end
  end
end

---@generic T
---@param list T[]
---@param cb function(value: `T`): boolean
---@return integer
function M.find_index(list, cb)
  for i, value in ipairs(list) do
    if cb(value) then
      return i
    end
  end
  return -1
end

function M.augroup(name)
  return vim.api.nvim_create_augroup("trek_" .. name, { clear = true })
end

function M.notify(msg, level_name)
  vim.notify("(trek.nvim) " .. msg, vim.log.levels[level_name])
end

---@class (exact) trek.Adapter
---@field name string The unique name of the adapter (this will be set automatically)
---@field list fun(path: string, column_defs: string[], cb: fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())) Async function to list a directory.
---@field is_modifiable fun(bufnr: integer): boolean Return true if this directory is modifiable (allows for directories with read-only permissions).
---@field get_column fun(name: string): nil|oil.ColumnDefinition If the adapter has any adapter-specific columns, return them when fetched by name.
---@field get_parent? fun(bufname: string): string Get the parent url of the given buffer
---@field normalize_url fun(url: string, callback: fun(url: string)) Before oil opens a url it will be normalized. This allows for link following, path normalizing, and converting an oil file url to the actual path of a file.
---@field get_entry_path? fun(url: string, entry: oil.Entry, callback: fun(path: string)) Similar to normalize_url, but used when selecting an entry
---@field render_action? fun(action: trek.FS_Action): string Render a mutation action for display in the preview window. Only needed if adapter is modifiable.
---@field perform_action? fun(action: trek.FS_Action, cb: fun(err: nil|string)) Perform a mutation action. Only needed if adapter is modifiable.
---@field read_file? fun(bufnr: integer) Used for adapters that deal with remote/virtual files. Read the contents of the file into a buffer.
---@field write_file? fun(bufnr: integer) Used for adapters that deal with remote/virtual files. Write the contents of a buffer to the destination.
---@field supported_cross_adapter_actions? table<string, oil.CrossAdapterAction> Mapping of adapter name to enum for all other adapters that can be used as a src or dest for move/copy actions.
---@field filter_action? fun(action: trek.FS_Action): boolean When present, filter out actions as they are created
---@field filter_error? fun(action: trek.FS_Action): boolean When present, filter out errors from parsing a buffer

---@param scheme nil|string
---@return nil|trek.Adapter
function M.get_adapter_by_scheme(scheme)
  ---TODO:: implement, but we dont need it to be as complex as in oil
  ---seems like in the lsp stuff it's only used for the name property
  return { name = "files" }
end

---@param path string
---@return string
function M.posix_to_os_path(path)
  if M.is_windows then
    if vim.startswith(path, "/") then
      local drive = path:match("^/(%a+)")
      local rem = path:sub(drive:len() + 2)
      return string.format("%s:%s", drive, rem:gsub("/", "\\"))
    else
      local newpath = path:gsub("/", "\\")
      return newpath
    end
  else
    return path
  end
end

M.abspath = function(path)
  if not M.is_absolute(path) then
    path = vim.fn.fnamemodify(path, ":p")
  end
  return path
end

M.is_absolute = function(dir)
  if M.is_windows then
    return dir:match("^%a:\\")
  else
    return vim.startswith(dir, "/")
  end
end

function M.set_buflines(buf_id, lines)
  local cmd =
    string.format("lockmarks lua vim.api.nvim_buf_set_lines(%d, 0, -1, false, %s)", buf_id, vim.inspect(lines))
  vim.cmd(cmd)
end

--- Returns true if candidate is a subpath of root, or if they are the same path.
---@param root string
---@param candidate string
---@return boolean
M.is_subpath = function(root, candidate)
  if candidate == "" then
    return false
  end
  root = vim.fs.normalize(M.abspath(root))
  -- Trim trailing "/" from the root
  if root:find("/", -1) then
    root = root:sub(1, -2)
  end
  candidate = vim.fs.normalize(M.abspath(candidate))
  if M.is_windows then
    root = root:lower()
    candidate = candidate:lower()
  end
  if root == candidate then
    return true
  end
  local prefix = candidate:sub(1, root:len())
  if prefix ~= root then
    return false
  end

  local candidate_starts_with_sep = candidate:find("/", root:len() + 1, true) == root:len() + 1
  local root_ends_with_sep = root:find("/", root:len(), true) == root:len()

  return candidate_starts_with_sep or root_ends_with_sep
end

---@param path string
---@return "file"|"directory"|nil
function M.get_path_type(path)
  local expanded_path = vim.fn.expand(path)
  if vim.fn.filereadable(expanded_path) == 1 then
    return "file"
  elseif vim.fn.isdirectory(expanded_path) == 1 then
    return "directory"
  else
    return nil
  end
end

---@param url string
---@return nil|string
---@return nil|string
function M.parse_url(url)
  local scheme, path = url:match("^(.+://)(.*)$")
  if scheme and path then
    return scheme, path
  else
    return "", url -- Return empty string as scheme and full url as path for local paths
  end
end

---@param line string
function M.match_line_path_id(line)
  if line == nil then
    return nil
  end

  local id_str = line:match("^/(%d+)")
  local ok, res = pcall(tonumber, id_str)
  if not ok then
    return nil
  end
  return res
end

--- @return string | nil
function M.track_dir_edit(data)
  -- Make early returns
  if vim.api.nvim_get_current_buf() ~= data.buf then
    return
  end

  if vim.b.minifiles_processed_dir then
    -- Smartly delete directory buffer if already visited
    local alt_buf = vim.fn.bufnr("#")
    if alt_buf ~= data.buf and vim.fn.buflisted(alt_buf) == 1 then
      vim.api.nvim_win_set_buf(0, alt_buf)
    end
    return vim.api.nvim_buf_delete(data.buf, { force = true })
  end

  local path = vim.api.nvim_buf_get_name(0)
  if vim.fn.isdirectory(path) ~= 1 then
    return
  end

  -- Make directory buffer disappear when it is not needed
  vim.bo.bufhidden = "wipe"
  vim.b.minifiles_processed_dir = true

  -- Open directory without history
  return path
end

---@param line string
function M.match_line_entry_name(line)
  if line == nil then
    return nil
  end
  local offset = M.match_line_offset(line)
  -- Go up until first occurrence of path separator allowing to track entries
  -- like `a/b.lua` when creating nested structure
  if offset == nil then
    return nil
  end
  local res = line:sub(offset):gsub("/.*$", "")
  return res
end

---@param line string
---@return integer|nil
function M.match_line_offset(line)
  if line == nil then
    return nil
  end
  return line:match("^/.-/.-/()") or 1
end

---@param buf_id integer
---@param row integer
M.get_bufline = function(buf_id, row)
  return vim.api.nvim_buf_get_lines(buf_id, row - 1, row, false)[1]
end

---@param event_name string
---@param data table
function M.trigger_event(event_name, data)
  if M.block_event_trigger[event_name] then
    return
  end
  vim.api.nvim_exec_autocmds("User", { pattern = event_name, data = data })
end

return M
