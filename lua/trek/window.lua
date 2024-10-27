local utils = require("trek.utils")
local M = {}

---@class trek.Window
---@field left_win_id integer
---@field center_win_id integer
---@field right_win_id integer
---@field left_buf_id integer
---@field center_buf_id integer
---@field right_buf_id integer
---@field tab_id integer

---@return trek.Window
function M.open()
  ---@class trek.Window
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
  return window
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

function M.window_set_cursor(win_id, cursor)
  if type(cursor) ~= "table" then
    return
  end

  vim.api.nvim_win_set_cursor(win_id, cursor)

  -- Tweak cursor here and don't rely on `CursorMoved` event to reduce flicker
  M.window_tweak_cursor(win_id, vim.api.nvim_win_get_buf(win_id))
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

return M
