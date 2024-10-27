local fs = require("trek.fs")
local highlights = require("trek.highlights")
local buffer = require("trek.buffer")
local utils = require("trek.utils")
---@class trek.Window
---@field window trek.WindowData
---@field opened_from_path string
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
  window.left_buf_id = vim.api.nvim_create_buf(false, true)
  window.center_buf_id = vim.api.nvim_create_buf(false, true)
  window.right_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(window.left_win_id, window.left_buf_id)
  vim.api.nvim_win_set_buf(window.center_win_id, window.center_buf_id)
  vim.api.nvim_win_set_buf(window.right_win_id, window.right_buf_id)
  vim.api.nvim_buf_set_name(window.center_buf_id, "Trek File Explorer")
  window.tab_id = vim.api.nvim_get_current_tabpage()
  M.window = window
  M.opened = true
  return window
end

function M.close()
  vim.api.nvim_buf_delete(M.window.left_buf_id, { force = true })
  vim.api.nvim_buf_delete(M.window.center_buf_id, { force = true })
  vim.api.nvim_buf_delete(M.window.right_buf_id, { force = true })
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
    local dir = fs.get_dir_content(entry.path)
    M.render_dir(dir, M.window.right_buf_id)
  end
  if entry.fs_type == "file" then
    buffer.buffer_update_file(M.window.right_buf_id, entry.path)
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
  M.render_dir(dir, M.window.center_buf_id)
  if entry_row ~= -1 then
    local cursor = vim.api.nvim_win_get_cursor(M.window.center_win_id)
    cursor[1] = entry_row
    vim.schedule(function()
      M.set_cursor(M.window.center_win_id, cursor)
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
  M.render_dir(dir, M.window.left_buf_id)
  local cursor = vim.api.nvim_win_get_cursor(M.window.left_win_id)
  cursor[1] = parent_entry_row
  vim.schedule(function()
    M.set_cursor(M.window.left_win_id, cursor)
  end)
end

---@param dir trek.Directory
---@param buf_id integer
function M.render_dir(dir, buf_id)
  local lines = utils.map(
    dir.entries,
    ---@param entry trek.DirectoryEntry
    function(entry)
      local icon = M.get_icon(entry)
      return "/" .. entry.id .. "/" .. icon .. " /" .. entry.name
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
  else
    print("No original options stored for window " .. win_id)
  end
end

---@param left_win_id integer
---@param center_win_id integer
M.mark_dirty = vim.schedule_wrap(function(left_win_id, center_win_id)
  highlights.set_modified_winsep(left_win_id, highlights.colors.warning)
  highlights.set_modified_winsep(center_win_id, highlights.colors.warning)
end)

---@param left_win_id integer
---@param center_win_id integer
M.mark_clean = vim.schedule_wrap(function(left_win_id, center_win_id)
  highlights.set_modified_winsep(left_win_id, highlights.colors.base)
  highlights.set_modified_winsep(center_win_id, highlights.colors.base)
end)

return M
