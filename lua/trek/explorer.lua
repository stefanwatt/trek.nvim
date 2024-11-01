local utils = require("trek.utils")
local config = require("trek.config")
local buffer = require("trek.buffer")
local highlights = require("trek.highlights")
local window = require("trek.window")
local fs = require("trek.fs")

---@class trek.Explorer
---@field path string
---@field tab_id integer
---@field opened boolean
---@field window trek.WindowData
---@field cursor integer[]
---@field selected_entry trek.DirectoryEntry
---@field cursor_autocmd_id integer
---@field buf_dir_changed boolean
local M = {
  opened = false,
  buf_dir_changed = false,
  cursor_history = {},
}

function M.teardown()
  M.path = nil
  M.tab_id = nil
  M.window = nil
  M.cursor = nil
  M.opened = false
  assert(M.cursor_autocmd_id ~= nil, "tried to delete cursor tracking autocmd, but id was nil")
  vim.api.nvim_del_autocmd(M.cursor_autocmd_id)
  window.close()
end

---@param path string
function M.open(path)
  M.path = path
  M.window = window.open()
  --TODO can get rid of M.path and just use M.dir.path
  M.dir = fs.get_dir_content(path)
  M.listen_for_center_buf_changes()
  window.mark_clean(M.window.left_win_id, M.window.center_win_id)
  M.opened = true
  window.resize_windows(M.window.left_win_id, M.window.center_win_id, M.window.right_win_id)
  window.render_dirs(path)
  for _, win_id in ipairs({ M.window.left_win_id, M.window.center_win_id, M.window.right_win_id }) do
    window.set_window_opts(win_id)
  end
  M.track_cursor()
  window.store_cursor_pos(M.path, M.window.center_win_id)
  M.setup_keymaps()
end

function M.listen_for_center_buf_changes()
  buffer.on_lines_changed(M.window.center_buf_id, function(first_line, last_line)
    if not M.opened then
      return true
    end
    if M.buf_dir_changed then
      M.buf_dir_changed = false
      return true
    end
    window.mark_dirty(M.window.left_win_id, M.window.center_win_id)
    M.dir.entries = buffer.parse_entries(M.window.center_buf_id, M.dir.entries)
  end)
end

function M.close()
  local current_tab_id = vim.api.nvim_get_current_tabpage()
  if current_tab_id ~= M.window.tab_id then
    return
  end
  M.teardown()
  --TODO why does this say it's the last tab page
  pcall(vim.cmd, "tabc")
end

function M.synchronize()
  local fs_actions = fs.compute_fs_actions(M.path, M.window.center_buf_id)
  if fs_actions ~= nil then
    fs.apply_fs_actions(fs_actions)
  end

  window.render_dirs(M.path)
  M.selected_entry = M.update_selected_entry()
  assert(M.selected_entry ~= nil, "selected_entry cannot be nil after go synchronize")
  M.dir = fs.get_dir_content(M.path)
  window.mark_clean(M.window.left_win_id, M.window.center_win_id)
end

function M.go_in()
  assert(M.selected_entry ~= nil, "selected_entry is nil")
  if M.selected_entry.id == -1 then
    return
  end
  if M.selected_entry.fs_type == "file" then
    M.close()
    M.open_file(0, M.selected_entry.path)
    window.restore_window_opts(vim.api.nvim_get_current_win())
    return
  end
  M.update_path(M.selected_entry.path)
  M.buf_dir_changed = true
  window.render_dirs(M.path)
  M.dir = fs.get_dir_content(M.path)
  M.selected_entry = M.update_selected_entry()
  assert(M.selected_entry ~= nil, "selected_entry cannot be nil after go in")
  window.mark_clean(M.window.left_win_id, M.window.center_win_id)
  window.restore_cursor_pos(M.path, M.window.center_win_id)
  M.listen_for_center_buf_changes()
end

function M.go_out()
  local parent_path = fs.get_parent(M.path)
  if parent_path == nil or parent_path == "/" then
    return
  end
  M.dir = fs.get_dir_content(parent_path)
  local parent_entry_row = utils.find_index(M.dir.entries, function(entry)
    return entry.path == M.path
  end)
  M.update_path(parent_path)
  M.buf_dir_changed = true
  window.render_dirs(parent_path)
  M.selected_entry = M.update_selected_entry()
  assert(M.selected_entry ~= nil, "selected_entry cannot be nil after go out")
  window.mark_clean(M.window.left_win_id, M.window.center_win_id)
  M.listen_for_center_buf_changes()
  if parent_entry_row == -1 then
    return
  end
  window.set_cursor(M.window.center_win_id, parent_entry_row)
end

---@param path string
function M.update_path(path)
  window.store_cursor_pos(M.path, M.window.center_win_id)
  M.path = path
end

function M.open_file(win_id, path)
  vim.api.nvim_win_call(win_id, function()
    vim.cmd("e " .. path)
    vim.cmd("filetype detect")
  end)
end

function M.track_cursor()
  --TODO delete autocmd in teardown
  M.cursor_autocmd_id = vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = utils.augroup("trek.Cursor"),
    callback = function()
      local updated_cursor = vim.api.nvim_win_get_cursor(M.window.center_win_id)
      if M.cursor ~= nil and M.cursor[1] ~= updated_cursor[1] then
        local selected_entry = M.update_selected_entry()
        if selected_entry ~= nil then
          M.selected_entry = selected_entry
        end
      end
      M.cursor = window.tweak_cursor(M.window.center_win_id, M.window.center_buf_id)
    end,
    buffer = M.window.center_buf_id,
  })
end

---@return trek.DirectoryEntry
function M.update_selected_entry()
  assert(M.opened, "explorer not open")
  local dir = fs.get_dir_content(M.path)
  assert(dir ~= nil, "dir nil")
  M.update_dir(dir)
  local selected_entry = window.update_selected_entry(M.dir.entries)
  window.render_preview(selected_entry)
  return selected_entry
end

---@param dir trek.Directory
function M.update_dir(dir)
  assert(dir ~= nil, "dir nil")
  assert(M.dir ~= nil, "M.dir nil")
  for i, entry in ipairs(M.dir.entries) do
    if entry.path ~= nil then
      local updated_entry = utils.find(dir.entries, function(new_entry)
        return new_entry.path == entry.path
      end)
      M.dir.entries[i] = updated_entry ~= nil and updated_entry or entry
    end
  end
end

function M.setup_keymaps()
  local opts = { silent = true, buffer = M.window.center_buf_id }
  local keymaps = config.get_config().keymaps
  vim.keymap.set("n", keymaps.go_out, M.go_out, opts)
  vim.keymap.set("n", keymaps.go_in, M.go_in, opts)
  vim.keymap.set("n", keymaps.close, M.close, opts)
  vim.keymap.set("n", keymaps.synchronize, M.synchronize, opts)
end

return M
