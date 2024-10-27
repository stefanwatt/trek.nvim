local utils = require("trek.utils")
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
local M = {}

---@param path string
function M.open(path)
  M.path = path
  M.window = window.open()
  M.mark_clean()
  M.opened = true
  window.resize_windows(M.window.left_win_id, M.window.center_win_id, M.window.right_win_id)
  M.render_dirs(path)
  for _, win_id in ipairs({ M.window.left_win_id, M.window.center_win_id, M.window.right_win_id }) do
    view.set_window_opts(win_id)
  end
  M.track_cursor()
  M.setup_keymaps()
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
end

function M.select_entry()
  --TODO validate selected_entry
  if M.selected_entry == nil then
    return
  end
  if M.selected_entry.fs_type == "file" then
    M.close()
    view.open_file(0, M.selected_entry.path)
    view.restore_window_opts(vim.api.nvim_get_current_win())
    return
  end
  M.path = M.selected_entry.path
  M.render_dirs(M.path)
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
    buffer = M.window.center_buf_id
  })
end

function M.update_preview()
  if not M.opened then
    return
  end
  local row = vim.api.nvim_win_get_cursor(M.window.center_win_id)[1]
  local dir = fs.get_dir_content(M.path)
  if dir == nil then
    return
  end
  if M.selected_entry ~= nil and M.selected_entry.fs_type == "file" then
    M.clean_buffer()
  end
  M.selected_entry = dir.entries[row]
  M.render_preview(M.selected_entry)
end

function M.clean_buffer()
  local buf_id = vim.api.nvim_win_get_buf(M.window.right_win_id)
  local tmp_buf_id = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_win_set_buf(M.window.right_win_id, tmp_buf_id)
  vim.api.nvim_buf_delete(buf_id, { force = true })
end

---@param entry trek.DirectoryEntry
function M.render_preview(entry)
  if entry.fs_type == "directory" then
    vim.api.nvim_win_set_buf(M.window.right_win_id, M.window.right_buf_id)
    M.render_dir(entry.path, M.window.right_buf_id)
  end
  if entry.fs_type == "file" then
    view.open_file(M.window.right_win_id, M.selected_entry.path)
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

function M.mark_dirty()
  highlights.set_modified_winsep(M.window.left_win_id, highlights.colors.warning)
  highlights.set_modified_winsep(M.window.center_win_id, highlights.colors.warning)
end

function M.mark_clean()
  highlights.set_modified_winsep(M.window.left_win_id, highlights.colors.base)
  highlights.set_modified_winsep(M.window.center_win_id, highlights.colors.base)
end

return M
