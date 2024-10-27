local fs = require("trek.fs")
local buffer = require("trek.buffer")
local view = require("trek.view")
local utils = require("trek.utils")
---@class trek.Window
---@field window trek.WindowData
local M = {
  cursor_history = {},
  opened = false,
}

---@class trek.WindowData
---@field left_win_id integer
---@field center_win_id integer
---@field right_win_id integer
---@field left_buf_id integer
---@field center_buf_id integer
---@field right_buf_id integer
---@field tab_id integer

---@return trek.WindowData
function M.open()
  ---@class trek.WindowData
  local window = {}
  vim.cmd("tabnew")
  window.left_win_id = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  window.center_win_id = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  window.right_win_id = vim.api.nvim_get_current_win()
  window.left_buf_id = vim.api.nvim_create_buf(true, false)
  window.center_buf_id = vim.api.nvim_create_buf(true, false)
  window.right_buf_id = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(window.left_win_id, window.left_buf_id)
  vim.api.nvim_win_set_buf(window.center_win_id, window.center_buf_id)
  vim.api.nvim_win_set_buf(window.right_win_id, window.right_buf_id)
  window.tab_id = vim.api.nvim_get_current_tabpage()
  M.window = window
  M.opened = true
  return window
end

function M.close()
  M.opened = false
end

---@param left_win number
---@param center_win number
---@param right_win number
function M.resize_windows(left_win, center_win, right_win)
  local total_width = vim.o.columns
  local small_width = math.floor(total_width * 0.25)
  local large_width = math.floor(total_width * 0.5)

  vim.api.nvim_win_set_width(left_win, small_width)
  vim.api.nvim_win_set_width(center_win, small_width)
  vim.api.nvim_win_set_width(right_win, large_width)
end

function M.set_cursor(win_id, cursor)
  if type(cursor) ~= "table" then
    return
  end

  vim.api.nvim_win_set_cursor(win_id, cursor)

  -- Tweak cursor here and don't rely on `CursorMoved` event to reduce flicker
  M.tweak_cursor(win_id, vim.api.nvim_win_get_buf(win_id))
end

function M.tweak_cursor(win_id, buf_id)
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local l = utils.get_bufline(buf_id, cursor[1])

  local cur_offset = utils.match_line_offset(l)
  if cursor[2] < (cur_offset - 1) then
    cursor[2] = cur_offset - 1
    vim.api.nvim_win_set_cursor(win_id, cursor)
    -- Ensure icons are shown (may be not the case after horizontal scroll)
    vim.cmd("normal! 1000zh")
  end

  return cursor
end

---@param path string
---@param win_id integer
function M.store_cursor_pos(path, win_id)
  M.cursor_history[path] = vim.api.nvim_win_get_cursor(win_id)
end

---@param path string
---@param win_id integer
function M.restore_cursor_pos(path, win_id)
  local cursor = M.cursor_history[path]
  if cursor == nil then
    return
  end
  vim.api.nvim_win_set_cursor(win_id, cursor)
end

---@param entry trek.DirectoryEntry
function M.render_preview(entry)
  if entry == nil then
    return
  end
  if entry.fs_type == "directory" then
    vim.api.nvim_win_set_buf(M.window.right_win_id, M.window.right_buf_id)
    M.render_dir(entry.path, M.window.right_buf_id)
  end
  if entry.fs_type == "file" then
    buffer.buffer_update_file(M.window.right_buf_id, entry.path)
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

---@param path string
---@return trek.DirectoryEntry | nil
function M.update_selected_entry(path)
  if not M.opened then
    return nil
  end
  local dir = fs.get_dir_content(path)
  if dir == nil then
    return nil
  end
  M.tweak_cursor(M.window.center_win_id, M.window.center_buf_id)
  local row = vim.api.nvim_win_get_cursor(M.window.center_win_id)[1]
  return dir.entries[row]
end

return M
