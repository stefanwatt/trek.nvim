local fs = require("trek.fs")
local highlights = require("trek.highlights")
local buffer = require("trek.buffer")
local utils = require("trek.utils")

local icon_checked = "󰄲"
local icon_not_checked = "󰄮"

local function get_default_window()
  return {
    left = { win_id = nil, buf_id = nil },
    center = { win_id = nil, buf_id = nil },
    right = { win_id = nil, buf_id = nil },
    selection_mode_info = { win_id = nil, buf_id = nil },
  }
end

---@class trek.Window
---@field window trek.WindowData
---@field opened_from_path string
---TODO: this seems sketchy
local M = {
  cursor_history = {},
  opened = false,
  window = get_default_window()
}

---@class trek.WindowPane
---@field win_id integer | nil
---@field buf_id integer | nil
---
---@class trek.WindowData
---@field left trek.WindowPane
---@field center trek.WindowPane
---@field right trek.WindowPane
---@field selection_mode_info trek.WindowPane

---@return trek.WindowData
function M.open()
  ---@class trek.WindowData
  local window = get_default_window()
  print('open window')
  vim.cmd("tabnew")
  window.left.win_id = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  window.center.win_id = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  window.right.win_id = vim.api.nvim_get_current_win()
  window.left.buf_id = vim.api.nvim_create_buf(false, true)
  window.center.buf_id = vim.api.nvim_create_buf(false, true)
  window.right.buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(window.left.win_id, window.left.buf_id)
  vim.api.nvim_win_set_buf(window.center.win_id, window.center.buf_id)
  vim.api.nvim_win_set_buf(window.right.win_id, window.right.buf_id)
  vim.api.nvim_buf_set_name(window.center.buf_id, "Trek File Explorer")
  highlights.set_cursorline(window.left.win_id, highlights.ns_id.left_window)
  highlights.set_cursorline(window.center.win_id, highlights.ns_id.center_window)
  window.tab_id = vim.api.nvim_get_current_tabpage()
  M.window = window
  M.opened = true
  return window
end

function M.close()
  vim.api.nvim_buf_delete(M.window.left.buf_id, { force = true })
  vim.api.nvim_buf_delete(M.window.center.buf_id, { force = true })
  vim.api.nvim_buf_delete(M.window.right.buf_id, { force = true })
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

---@param win_id integer
---@param row integer
function M.set_cursor(win_id, row)
  local cursor = vim.api.nvim_win_get_cursor(M.window.center.win_id)
  cursor[1] = row
  if type(cursor) ~= "table" then
    return
  end

  vim.api.nvim_win_set_cursor(win_id, cursor)

  -- Tweak cursor here and don't rely on `CursorMoved` event to reduce flicker
  M.tweak_cursor(win_id, vim.api.nvim_win_get_buf(win_id))
end

function M.reset_cursor(win_id, buf_id)
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local l = utils.get_bufline(buf_id, cursor[1])
  local cur_offset = utils.match_line_offset(l)
  cursor[2] = cur_offset - 1
  vim.api.nvim_win_set_cursor(win_id, cursor)
  vim.cmd("normal! 1000zh")
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
  if entry.id == -1 then
    return utils.set_buflines(M.window.right.buf_id, { "-file-not-created-" })
  end
  if entry.fs_type == "directory" then
    local dir = fs.get_dir_content(entry.path)
    M.render_dir(dir, M.window.right.buf_id)
  end
  if entry.fs_type == "file" then
    buffer.buffer_update_file(M.window.right.buf_id, entry.path)
  end
end

---@param path string
function M.render_current_dir(path)
  local dir = fs.get_dir_content(path)
  local entry_row = -1
  if M.opened_from_path ~= nil then
    entry_row = utils.find_index(dir.entries, function(entry)
      return entry.path == M.opened_from_path
    end)
  end
  M.render_dir(dir, M.window.center.buf_id)
  if entry_row ~= -1 then
    vim.schedule(function()
      M.set_cursor(M.window.center.win_id, entry_row)
    end)
  end
end

---@param parent_path string
---@param path string
function M.render_parent_dir(parent_path, path)
  local dir = fs.get_dir_content(parent_path)
  local parent_entry_row = utils.find_index(dir.entries, function(entry)
    return entry.path == path
  end)
  M.render_dir(dir, M.window.left.buf_id)
  vim.schedule(function()
    M.set_cursor(M.window.left.win_id, parent_entry_row)
  end)
end

---@param dir trek.Directory
---@param buf_id integer
function M.render_dir(dir, buf_id)
  local is_selection_mode = utils.find_index(dir.entries, function(entry)
    return entry.marked
  end) ~= -1
  local lines = utils.map(
    dir.entries,
    ---@param entry trek.DirectoryEntry
    function(entry)
      local icon = M.get_icon(entry)
      local checkbox = ""
      if is_selection_mode then
        checkbox = entry.marked and icon_checked or icon_not_checked
        checkbox = checkbox .. "  "
      end
      return "/" .. entry.id .. "/" .. checkbox .. icon .. " /" .. entry.name
    end
  )
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
  highlights.add_highlights(buf_id, dir.entries)
end

---@param path string
function M.render_dirs(path)
  M.render_current_dir(path)
  local parent_path = fs.get_parent(path)
  if parent_path ~= nil then
    M.render_parent_dir(parent_path, path)
  end
  vim.api.nvim_set_current_win(M.window.center.win_id)
end

---@param entries trek.DirectoryEntry[]
---@return trek.DirectoryEntry
function M.update_selected_entry(entries)
  --NOTE not sure if I like this, could be annoying in visual mode etc.
  M.reset_cursor(M.window.center.win_id, M.window.center.buf_id)
  local row = vim.api.nvim_win_get_cursor(M.window.center.win_id)[1]
  return entries[row]
end

---@param entry trek.DirectoryEntry
---@return string
function M.get_icon(entry)
  if entry.fs_type == "directory" then
    return " "
  end
  local has_devicons, devicons = pcall(require, "nvim-web-devicons")
  if not has_devicons then
    return " "
  end

  local icon, hl = devicons.get_icon(entry.name, nil, { default = false })
  return (icon or "") .. " "
end

function M.set_window_opts(win_id)
  M.original_win_opts = {
    number = vim.api.nvim_win_get_option(win_id, "number"),
    relativenumber = vim.api.nvim_win_get_option(win_id, "relativenumber"),
    cursorline = vim.wo[win_id].cursorline,
    conceallevel = vim.wo[win_id].conceallevel,
    concealcursor = vim.wo[win_id].concealcursor,
    foldenable = vim.wo[win_id].foldenable,
    wrap = vim.wo[win_id].wrap,
  }
  vim.api.nvim_win_set_option(win_id, "number", false)
  vim.api.nvim_win_set_option(win_id, "relativenumber", false)
  vim.api.nvim_win_call(win_id, function()
    vim.fn.matchadd("Conceal", [[^/\d\+/]])
    vim.fn.matchadd("Conceal", [[^/\d\+/[^/]*\zs/\ze]])
  end)
  vim.wo[win_id].cursorline = true
  vim.wo[win_id].conceallevel = 3
  vim.wo[win_id].concealcursor = "nvic"
  vim.wo[win_id].foldenable = false
  vim.wo[win_id].wrap = false
end

---@param win_id integer
function M.restore_window_opts(win_id)
  if M.original_win_opts then
    local opts = M.original_win_opts
    vim.api.nvim_win_set_option(win_id, "number", opts.number)
    vim.api.nvim_win_set_option(win_id, "relativenumber", opts.relativenumber)
    vim.wo[win_id].cursorline = opts.cursorline
    vim.wo[win_id].conceallevel = opts.conceallevel
    vim.wo[win_id].concealcursor = opts.concealcursor
    vim.wo[win_id].foldenable = opts.foldenable
    vim.wo[win_id].wrap = opts.wrap
    M.original_win_opts = nil
    vim.api.nvim_win_call(win_id, function()
      vim.fn.clearmatches()
    end)
  end
end

---@param left_win_id integer
---@param center_win_id integer
M.mark_dirty = vim.schedule_wrap(function(left_win_id, center_win_id)
  highlights.set_modified_winsep(
    left_win_id,
    highlights.ns_id.left_window,
    highlights.colors.warning
  )
  highlights.set_modified_winsep(
    center_win_id,
    highlights.ns_id.center_window,
    highlights.colors.warning
  )
end)

---@param left_win_id integer
---@param center_win_id integer
M.mark_clean = vim.schedule_wrap(function(left_win_id, center_win_id)
  highlights.set_modified_winsep(
    left_win_id,
    highlights.ns_id.left_window,
    highlights.colors.dark
  )
  highlights.set_modified_winsep(
    center_win_id,
    highlights.ns_id.center_window,
    highlights.colors.dark
  )
end)

function M.hide_selection_mode_info()
  if M.window.selection_mode_info.win_id == nil then return end
  vim.api.nvim_win_close(M.window.selection_mode_info.win_id, true)
  M.window.selection_mode_info.win_id = nil
  M.window.selection_mode_info.buf_id = nil
end

---@param text string
function M.create_selection_mode_info_win(text)
  M.window.selection_mode_info.buf_id = vim.api.nvim_create_buf(false, true)
  local win_width = vim.api.nvim_win_get_width(M.window.center.win_id)
  local win_height = vim.api.nvim_win_get_height(M.window.center.win_id)

  local ns = vim.api.nvim_create_namespace("TrekSelectionModeInfo")
  vim.api.nvim_set_hl(ns, "CursorLine", { bg = highlights.colors.normal, fg = highlights.colors.text })
  M.window.selection_mode_info.win_id = vim.api.nvim_open_win(M.window.selection_mode_info.buf_id, false, {
    relative = 'win',
    width = #text + 4,
    height = 1,
    row = win_height,
    col = win_width,
    anchor = "SE",
    border = "rounded",
    win = M.window.center.win_id,
  })
  vim.api.nvim_win_set_hl_ns(M.window.selection_mode_info.win_id, ns)
end

---@param number_marked_entries integer
function M.show_selection_mode_info(number_marked_entries)
  local text = M.get_selection_mode_info_text(number_marked_entries)
  if M.window.selection_mode_info.win_id == nil then
    M.create_selection_mode_info_win(text)
  end
  utils.set_buflines(M.window.selection_mode_info.buf_id, { text })
end

---@param number_marked_entries integer
function M.get_selection_mode_info_text(number_marked_entries)
  return tostring(number_marked_entries) .. " items selected"
end

return M
