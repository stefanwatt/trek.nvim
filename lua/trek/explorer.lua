local utils = require("trek.utils")
local buffer = require("trek.buffer")
local highlights = require("trek.highlights")
local window = require("trek.window")
local view = require("trek.view")
local fs = require("trek.fs")

local function augroup(name)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end

---@class trek.Explorer
---@field path string
---@field tab_id integer
---@field opened boolean
local M = {
  cursor_history = {},
}

function M.teardown()
  --TODO clean up everything
end

---@param path string
function M.open(path)
  M.path = path
  M.window = window.open()
  buffer.on_lines_changed(M.window.center_buf_id, function(first_line, last_line)
    M.mark_dirty()
  end)
  -- prints: { "lines", 17, 6, 0, 2, 2, 37 }
  -- • on_lines: Lua callback invoked on change. Return `true` to detach. Args:
  --                   • the string "lines"
  --                   • buffer handle
  --                   • b:changedtick
  --                   • first line that changed (zero-indexed)
  --                   • last line that was changed
  --                   • last line in the updated range
  --                   • byte count of previous contents
  --                   • deleted_codepoints (if `utf_sizes` is true)
  --                   • deleted_codeunits (if `utf_sizes` is true)

  M.mark_clean()
  M.opened = true
  window.resize_windows(M.window.left_win_id, M.window.center_win_id, M.window.right_win_id)
  M.render_dirs(path)
  for _, win_id in ipairs({ M.window.left_win_id, M.window.center_win_id, M.window.right_win_id }) do
    view.set_window_opts(win_id)
  end
  M.track_cursor()
  M.store_cursor_pos()
  M.setup_keymaps()
end

function M.store_cursor_pos()
  M.cursor_history[M.path] = vim.api.nvim_win_get_cursor(M.window.center_win_id)
end

function M.restore_cursor_pos()
  local cursor = M.cursor_history[M.path]
  if cursor == nil then
    return
  end
  vim.api.nvim_win_set_cursor(M.window.center_win_id, cursor)
end

function M.close()
  M.opened = false
  local current_tab_id = vim.api.nvim_get_current_tabpage()
  if current_tab_id ~= M.window.tab_id then
    return
  end
  vim.cmd("tabc")
end

function M.setup_keymaps()
  local opts = { silent = true, buffer = M.window.center_buf_id }
  vim.keymap.set("n", "<Left>", M.up_one_dir, opts)
  vim.keymap.set("n", "<Right>", M.select_entry, opts)
  vim.keymap.set("n", "q", M.close, opts)
  vim.keymap.set("n", "=", M.synchronize, opts)
end

function M.synchronize()
  local fs_actions = M.compute_fs_actions()
  if fs_actions ~= nil then
    fs.apply_fs_actions(fs_actions)
  end

  M.render_dirs(M.path)
  M.cursor_changed()
  M.mark_clean()
end

function M.select_entry()
  --TODO validate selected_entry
  if M.selected_entry == nil then
    return
  end
  if M.selected_entry.fs_type == "file" then
    M.close()
    M.open_file(0, M.selected_entry.path)
    view.restore_window_opts(vim.api.nvim_get_current_win())
    return
  end
  M.update_path(M.selected_entry.path)
  M.render_dirs(M.path)
  M.cursor_changed()
  M.mark_clean()
  M.restore_cursor_pos()
end

---@param path string
function M.update_path(path)
  M.store_cursor_pos()
  M.path = path
end

function M.open_file(win_id, path)
  vim.api.nvim_win_call(win_id, function()
    vim.cmd("e " .. path)
    vim.cmd("filetype detect")
  end)
end

function M.up_one_dir()
  local parent_path = fs.get_parent(M.path)
  if parent_path == nil then
    return
  end
  M.update_path(parent_path)
  M.render_dirs(parent_path)
  M.cursor_changed()
  M.mark_clean()
  M.restore_cursor_pos()
end

function M.track_cursor()
  vim.api.nvim_create_autocmd({"CursorMoved","CursorMovedI" }, {
    group = augroup("trek.Cursor"),
    callback = M.cursor_changed,
    buffer = M.window.center_buf_id,
  })
end

function M.cursor_changed()
  if not M.opened then
    return
  end
  local row = vim.api.nvim_win_get_cursor(M.window.center_win_id)[1]
  local dir = fs.get_dir_content(M.path)
  if dir == nil then
    return
  end
  window.tweak_cursor(M.window.center_win_id, M.window.center_buf_id)
  M.selected_entry = dir.entries[row]
  M.render_preview(M.selected_entry)
end

---@param entry trek.DirectoryEntry
function M.render_preview(entry)
  if entry.fs_type == "directory" then
    vim.api.nvim_win_set_buf(M.window.right_win_id, M.window.right_buf_id)
    M.render_dir(entry.path, M.window.right_buf_id)
  end
  if entry.fs_type == "file" then
    buffer.buffer_update_file(M.window.right_buf_id, M.selected_entry.path)
  end
end

---@param path string
function M.render_current_dir(path)
  M.render_dir(path, M.window.center_buf_id)
end

---@param path string
function M.render_parent_dir(path)
  M.render_dir(path, M.window.left_buf_id)
end

---@param path string
---@param buf_id integer
function M.render_dir(path, buf_id)
  local dir = fs.get_dir_content(path)
  view.render_dir(dir.entries, buf_id)
end

---@param path string
function M.render_dirs(path)
  M.render_current_dir(path)
  local parent_path = fs.get_parent(path)
  if parent_path ~= nil then
    M.render_parent_dir(parent_path)
  end
  vim.api.nvim_set_current_win(M.window.center_win_id)
end

M.mark_dirty = vim.schedule_wrap(function()
  highlights.set_modified_winsep(M.window.left_win_id, highlights.colors.warning)
  highlights.set_modified_winsep(M.window.center_win_id, highlights.colors.warning)
end)

M.mark_clean = vim.schedule_wrap(function()
  highlights.set_modified_winsep(M.window.left_win_id, highlights.colors.base)
  highlights.set_modified_winsep(M.window.center_win_id, highlights.colors.base)
end)

function M.compute_fs_actions()
  -- Compute differences
  local dir = fs.get_dir_content(M.path)
  local children_ids = utils.map(dir.entries, function(entry)
    return entry.id
  end)
  local fs_diffs = {}
  local dir_fs_diff = buffer.compute_fs_diff(M.window.center_buf_id, M.path, children_ids)
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
      if fs.get_parent(diff.from) == fs.get_parent(diff.to) then
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

return M
