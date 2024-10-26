local utils = require("trek.utils")
local window = require("trek.window")
local view = require("trek.view")
local fs = require("trek.fs")

local function augroup(name)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end

---@class trek.Explorer
---@field path string
local M = {}

---@param path string
function M.open(path)
  M.path = path
  M.window = window.open()
  M.render_current_dir(path)
  local parent_path = fs.get_parent(path)
  if parent_path ~= nil then
    M.render_parent_dir(parent_path)
  end

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup("trek.Cursor"),
    callback = function(event)
      local row = vim.api.nvim_win_get_cursor(M.window.center_win_id)[1]
      local dir = fs.get_dir_content(M.path)
      if dir == nil then
        return
      end
      local current_entry = dir.entries[row]
      M.render_preview(current_entry.name)
    end,
  })
end

---@param content string
function M.render_preview(content)
  vim.api.nvim_buf_set_lines(M.window.right_buf_id, 0, -1, false, { content })
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
  local lines = view.get_dir_view(dir.entries)
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

return M
