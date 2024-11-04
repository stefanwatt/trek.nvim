local utils = require("trek.utils")
local config = require("trek.config")
local buffer = require("trek.buffer")
local highlights = require("trek.highlights")
local window = require("trek.window")
local fs = require("trek.fs")

---@class trek.Directory
---@field path string
---@field entries trek.DirectoryEntry[]

---@class trek.DirectoryEntry
---@field id integer
---@field fs_type "file" | "directory"
---@field name string
---@field path string
---@field icon string | nil
---@field icon_hl_group string | nil
---@field marked boolean

---@class trek.Explorer
---@field path string
---@field tab_id integer
---@field opened boolean
---@field window trek.WindowData
---@field cursor integer[]
---@field selected_entry trek.DirectoryEntry
---@field cursor_autocmd_id integer
---@field stop_listening_on_next_buf_change boolean
---@field dir trek.Directory
---@field mode "normal" | "selection"
---@field pending_fs_actions table<string, trek.FsActions>
---@field cursor_history table<string, table<integer>>
local M = {
  mode = "normal",
  dir = { path = "", entries = {} },
  opened = false,
  stop_listening_on_next_buf_change = false,
  cursor_history = {},
  pending_fs_actions = {},
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
  M.window = window.open()
  M.dir = fs.get_dir_content(path)
  M.listen_for_center_buf_changes()
  window.mark_clean()
  M.opened = true
  window.resize_windows(M.window.left.win_id, M.window.center.win_id, M.window.right.win_id)
  window.render_dirs(M.dir)
  for _, win_id in ipairs({ M.window.left.win_id, M.window.center.win_id, M.window.right.win_id }) do
    window.set_window_opts(win_id)
  end
  M.track_cursor()
  M.update_selected_entry()
  window.render_preview(M.selected_entry)
  window.store_cursor_pos(M.dir.path, M.window.center.win_id)
  M.setup_keymaps()
end

function M.listen_for_center_buf_changes()
  buffer.on_lines_changed(M.window.center.buf_id, function(first_line, last_line)
    if not M.opened then
      return true
    end
    if M.stop_listening_on_next_buf_change then
      M.stop_listening_on_next_buf_change = false
      return true
    end
    window.mark_dirty()
    M.dir.entries = buffer.parse_entries(M.window.center.buf_id, M.dir.entries)
  end)
end

function M.close()
  local current_tab_id = vim.api.nvim_get_current_tabpage()
  if current_tab_id ~= M.window.tab_id then
    return
  end
  M.teardown()
  --TODO: why does this say it's the last tab page
  pcall(vim.cmd, "tabc")
end

function M.synchronize()
  local fs_actions = fs.compute_fs_actions(M.dir.path, M.window.center.buf_id)
  if fs_actions == nil then
    M.dir.entries = utils.filter(M.dir.entries, function(entry)
      return entry.id ~= -1
    end)
    window.render_current_dir(M.dir)
    window.mark_clean()
    return
  end
  for path, pending_fs_actions in pairs(M.pending_fs_actions) do
    assert(
      pending_fs_actions ~= nil
        and pending_fs_actions.delete ~= nil
        and fs_actions.delete ~= nil
        and pending_fs_actions.copy ~= nil
        and fs_actions.copy ~= nil
        and pending_fs_actions.create ~= nil
        and fs_actions.create ~= nil
        and pending_fs_actions.move ~= nil
        and fs_actions.move ~= nil
        and pending_fs_actions.rename ~= nil
        and fs_actions.rename ~= nil,
      "fsactions: shouldnt be possible for any of this to be nil"
    )
    if path ~= M.path then
      fs_actions.delete = vim.tbl_deep_extend("force", fs_actions.delete, pending_fs_actions.delete)
      fs_actions.copy = vim.tbl_deep_extend("force", fs_actions.copy, pending_fs_actions.copy)
      fs_actions.create = vim.tbl_deep_extend("force", fs_actions.create, pending_fs_actions.create)
      fs_actions.move = vim.tbl_deep_extend("force", fs_actions.move, pending_fs_actions.move)
      fs_actions.rename = vim.tbl_deep_extend("force", fs_actions.rename, pending_fs_actions.rename)
    end
  end
  fs.apply_fs_actions(fs_actions)
  M.dir = fs.get_dir_content(M.dir.path)
  window.render_dirs(M.dir)
  M.selected_entry = window.update_selected_entry(M.dir.entries)
  assert(M.selected_entry ~= nil, "selected_entry cannot be nil after go synchronize")
  window.render_preview(M.selected_entry)
  window.mark_clean()
  M.pending_fs_actions = {}
end

function M.go_in()
  assert(M.selected_entry ~= nil, "selected_entry is nil")
  if M.selected_entry.id == -1 then
    return
  end
  M.pending_fs_actions[M.dir.path] = fs.compute_fs_actions(M.dir.path, M.window.center.buf_id)
  if M.selected_entry.fs_type == "file" then
    M.close()
    M.open_file(0, M.selected_entry.path)
    window.restore_window_opts(vim.api.nvim_get_current_win())
    return
  end
  M.update_path(M.selected_entry.path)
  M.stop_listening_on_next_buf_change = true
  window.render_dirs(M.dir)
  M.selected_entry = M.update_selected_entry()
  assert(M.selected_entry ~= nil, "selected_entry cannot be nil after go in")
  window.mark_clean()
  window.restore_cursor_pos(M.dir.path, M.window.center.win_id)
  M.listen_for_center_buf_changes()
end

function M.go_out()
  local parent_path = fs.get_parent(M.dir.path)
  if parent_path == nil or parent_path == "/" then
    return
  end
  M.pending_fs_actions[M.dir.path] = fs.compute_fs_actions(M.dir.path, M.window.center.buf_id)
  M.update_path(parent_path)
  local parent_entry_row = utils.find_index(M.dir.entries, function(entry)
    return entry.path == M.dir.path
  end)
  M.stop_listening_on_next_buf_change = true
  window.render_dirs(M.dir)
  M.selected_entry = M.update_selected_entry()
  assert(M.selected_entry ~= nil, "selected_entry cannot be nil after go out")
  window.mark_clean()
  M.listen_for_center_buf_changes()
  if parent_entry_row == -1 then
    return
  end
  window.set_cursor(M.window.center.win_id, parent_entry_row)
end

---@param path string
function M.update_path(path)
  window.store_cursor_pos(M.dir.path, M.window.center.win_id)
  M.dir = fs.get_dir_content(path)
end

function M.open_file(win_id, path)
  vim.api.nvim_win_call(win_id, function()
    vim.cmd("e " .. path)
    vim.cmd("filetype detect")
  end)
end

function M.track_cursor()
  M.cursor_autocmd_id = vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = utils.augroup("trek.Cursor"),
    callback = function()
      local updated_cursor = vim.api.nvim_win_get_cursor(M.window.center.win_id)
      if M.cursor ~= nil and M.cursor[1] ~= updated_cursor[1] then
        local selected_entry = M.update_selected_entry()
        if selected_entry ~= nil then
          M.selected_entry = selected_entry
        end
      end
      M.cursor = window.tweak_cursor(M.window.center.win_id, M.window.center.buf_id)
    end,
    buffer = M.window.center.buf_id,
  })
end

---@return trek.DirectoryEntry
function M.update_selected_entry()
  assert(M.opened, "explorer not open")
  local dir = fs.get_dir_content(M.dir.path)
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
      M.dir.entries[i].marked = entry.marked
    end
  end
end

function M.toggle_entry_marked()
  local row = vim.api.nvim_win_get_cursor(M.window.center.win_id)[1]
  local line = utils.get_bufline(M.window.center.buf_id, row)
  local path_id = utils.match_line_path_id(line)
  local entry_index = utils.find_index(M.dir.entries, function(entry)
    return entry.id == path_id
  end)
  assert(entry_index ~= -1, "tried to select an entry that doesn't exist in M.dir.entries")
  M.dir.entries[entry_index].marked = not M.dir.entries[entry_index].marked
  M.stop_listening_on_next_buf_change = true
  window.render_current_dir(M.dir)
  window.mark_clean()
  M.listen_for_center_buf_changes()
  local marked_entries = M.get_marked_entries()
  if #marked_entries > 1 then
    window.show_selection_mode_info(#marked_entries)
  else
    window.hide_selection_mode_info()
  end
  if #marked_entries > 0 and M.mode == "normal" then
    M.enter_selection_mode()
    return
  end
  if #marked_entries == 0 and M.mode == "selection" then
    M.exit_selection_mode()
  end
end

---@return trek.DirectoryEntry[]
function M.get_marked_entries()
  return utils.filter(M.dir.entries, function(entry)
    return entry.marked
  end)
end

function M.enter_selection_mode()
  M.mode = "selection"
  local opts = { silent = true, buffer = M.window.center.buf_id }
  vim.keymap.set("n", "y", function()
    M.yank_marked_entries()
    M.exit_selection_mode()
  end, opts)
  vim.keymap.set("n", "d", M.delete_marked_entries, opts)
  vim.keymap.set("n", "q", M.exit_selection_mode, opts)
  vim.keymap.set("n", "<Esc>", M.exit_selection_mode, opts)
end

function M.yank_marked_entries()
  local marked_entries = M.get_marked_entries()
  local rows = utils.map(marked_entries, function(entry)
    local row = utils.find_index(M.dir.entries, function(_entry)
      return _entry.id == entry.id
    end)
    assert(row ~= -1, "didnt find corresponding row to marked entry")
    return utils.get_bufline(M.window.center.buf_id, row)
  end)
  local yanked_text = table.concat(rows, "\n")
  vim.fn.setreg("0", yanked_text)
  vim.fn.setreg("+", yanked_text)
end

function M.delete_marked_entries()
  M.yank_marked_entries()
  local lines = vim.api.nvim_buf_get_lines(M.window.center.buf_id, 0, -1, false)
  lines = utils.filter(lines, function(line)
    local path_id = utils.match_line_path_id(line)
    local entry = utils.find(M.dir.entries, function(entry)
      return entry.id == path_id
    end)
    assert(entry ~= nil, "couldnt find entry to delete")
    return not entry.marked
  end)
  M.stop_listening_on_next_buf_change = true
  utils.set_buflines(M.window.center.buf_id, lines)
  M.listen_for_center_buf_changes()
  M.exit_selection_mode()
end

function M.exit_selection_mode()
  if M.mode == "normal" then
    return
  end
  window.hide_selection_mode_info()
  for _, entry in ipairs(M.dir.entries) do
    entry.marked = false
  end
  M.mode = "normal"
  local opts = { silent = true, buffer = M.window.center.buf_id }
  local keymaps = config.get_config().keymaps
  local selection_mode_keymaps = { "q", "<Esc>", "y", "d" }
  local user_keymaps = M.get_user_keymaps()
  for _, keymap in ipairs(selection_mode_keymaps) do
    vim.keymap.del("n", keymap, opts)
    for lhs, rhs in pairs(user_keymaps) do
      if lhs == keymap then
        vim.keymap.set("n", lhs, rhs, opts)
      end
    end
  end
  local modified = window.winbar.modified
  window.render_current_dir(M.dir)
  if not modified then
    window.mark_clean()
  end
end

---@return table<string, string|function>
function M.get_user_keymaps()
  local config_keymaps = config.get_config().keymaps
  return {
    [config_keymaps.go_out] = M.go_out,
    [config_keymaps.go_in] = M.go_in,
    [config_keymaps.close] = M.close,
    [config_keymaps.synchronize] = M.synchronize,
    [config_keymaps.toggle_entry_marked] = M.toggle_entry_marked,
    p = "o<Esc>p",
  }
end

function M.setup_keymaps()
  local opts = { silent = true, buffer = M.window.center.buf_id }
  local keymaps = M.get_user_keymaps()
  for lhs, rhs in pairs(keymaps) do
    vim.keymap.set("n", lhs, rhs, opts)
  end
end

return M
