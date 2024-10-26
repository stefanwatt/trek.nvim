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
  M.render_dirs(path)
  M.track_cursor()
  M.setup_keymaps()
end

function M.setup_keymaps()
  local opts = { silent = true, buffer = M.window.center_buf_id }
  vim.keymap.set("n", "<Left>", M.up_one_dir, opts)
  vim.keymap.set("n", "<Right>", M.select_entry, opts)
end

function M.select_entry()
  print("select entry")
  --TODO validate selected_entry
  local path = M.selected_entry.fs_type == "directory" and M.selected_entry.path
    or fs.get_directory_of_path(M.selected_entry.path)
  M.path = path
  M.render_dirs(path)
  M.update_preview()
end

function M.up_one_dir()
  print("up one dir")
  local parent_path = fs.get_parent(M.path)
  if parent_path ~= nil then
    M.path = parent_path
    M.render_dirs(parent_path)
    M.update_preview()
  end
end

function M.track_cursor()
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup("trek.Cursor"),
    callback = M.update_preview,
  })
end

function M.update_preview()
  local row = vim.api.nvim_win_get_cursor(M.window.center_win_id)[1]
  local dir = fs.get_dir_content(M.path)
  if dir == nil then
    return
  end
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
    vim.api.nvim_win_call(M.window.right_win_id, function()
      vim.cmd("e " .. entry.path)
    end)
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
  local lines = view.get_dir_view(dir.entries)
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
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

return M
