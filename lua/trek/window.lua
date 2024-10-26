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

return M