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
    window.mark_dirty(M.window.left_win_id, M.window.center_win_id)
  end)
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

function M.close()
  M.opened = false
  window.close()
  local current_tab_id = vim.api.nvim_get_current_tabpage()
  if current_tab_id ~= M.window.tab_id then
    return
  end
  M.teardown()
  vim.cmd("tabc")
end

function M.synchronize()
  local fs_actions = fs.compute_fs_actions(M.path, M.window.center_buf_id)
  if fs_actions ~= nil then
    fs.apply_fs_actions(fs_actions)
  end

  window.render_dirs(M.path)
  M.update_selected_entry()
  window.mark_clean(M.window.left_win_id, M.window.center_win_id)
end

function M.go_in()
  --TODO validate selected_entry
  if M.selected_entry == nil then
    return
  end
  if M.selected_entry.fs_type == "file" then
    M.close()
    M.open_file(0, M.selected_entry.path)
    window.restore_window_opts(vim.api.nvim_get_current_win())
    return
  end
  M.update_path(M.selected_entry.path)
  window.render_dirs(M.path)
  M.update_selected_entry()
  window.mark_clean(M.window.left_win_id, M.window.center_win_id)
  window.restore_cursor_pos(M.path, M.window.center_win_id)
end

function M.go_out()
  local parent_path = fs.get_parent(M.path)
  if parent_path == nil then
    return
  end
  local dir = fs.get_dir_content(parent_path)
  local parent_entry_row = utils.find_index(dir.entries, function(entry)
    return entry.path == M.path
  end)
  M.update_path(parent_path)
  window.render_dirs(parent_path)
  M.update_selected_entry()
  window.mark_clean(M.window.left_win_id, M.window.center_win_id)
  -- window.restore_cursor_pos(M.path, M.window.center_win_id)
  if parent_entry_row == -1 then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(M.window.center_win_id)
  cursor[1] = parent_entry_row
  vim.schedule(function()
    window.set_cursor(M.window.center_win_id, cursor)
  end)
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
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = utils.augroup("trek.Cursor"),
    callback = M.update_selected_entry,
    buffer = M.window.center_buf_id,
  })
end

function M.update_selected_entry()
  M.selected_entry = window.update_selected_entry(M.path)
  window.render_preview(M.selected_entry)
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
