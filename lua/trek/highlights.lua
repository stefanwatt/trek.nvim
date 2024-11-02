local utils = require("trek.utils")
local M = {
  ns_id = {
    highlight = vim.api.nvim_create_namespace("TrekHighlight"),
    left_window = vim.api.nvim_create_namespace("TrekLeftWindow"),
    center_window = vim.api.nvim_create_namespace("TrekCenterWindow"),
  },
  colors = {
    info = vim.fn.synIDattr(vim.fn.hlID("Directory"), "fg#"),
    warning = vim.fn.synIDattr(vim.fn.hlID("WarningMsg"), "fg#"),
    surface = vim.fn.synIDattr(vim.fn.hlID("LineNr"), "fg#"),
    dark = vim.fn.synIDattr(vim.fn.hlID("SignColumnSB"), "bg#"),
    normal = vim.fn.synIDattr(vim.fn.hlID("Normal"), "bg#"),
    text = vim.fn.synIDattr(vim.fn.hlID("Normal"), "fg#"),
  },
}

function M.buffer_should_highlight(buf_id)
  -- Highlight if buffer size is not too big, both in total and per line
  local buf_size = vim.api.nvim_buf_call(buf_id, function()
    return vim.fn.line2byte(vim.fn.line("$") + 1)
  end)
  return buf_size <= 1000000 and buf_size <= 1000 * vim.api.nvim_buf_line_count(buf_id)
end

function M.set_extmark(...)
  pcall(vim.api.nvim_buf_set_extmark, ...)
end

---@param win_id integer
---@param ns integer
function M.set_cursorline(win_id, ns)
  vim.api.nvim_set_hl(ns, "CursorLine", { bg = M.colors.info, fg = M.colors.dark })
  vim.api.nvim_win_set_hl_ns(win_id, ns)
end

---@param buf_id number
---@param entries trek.DirectoryEntry[]
function M.add_highlights(buf_id, entries)
  local ns_id = M.ns_id.highlight
  vim.api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)

  local set_hl = function(line, col, hl_opts)
    M.set_extmark(buf_id, ns_id, line, col, hl_opts)
  end

  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  local is_selection_mode = utils.find_index(entries, function(entry)
    return entry.marked
  end) ~= -1
  for i, entry in ipairs(entries) do
    local hl_group = entry.fs_type == "file" and "MiniFilesFile" or "MiniFilesDirectory"
    local line = lines[i]
    local icon_start, name_start = line:match("^/%d+/().-()/")
    icon_start = icon_start - 1
    if is_selection_mode then
      set_hl(i - 1, icon_start, { hl_group = "WarningMsg", end_col = icon_start + 1, right_gravity = false })
      icon_start = icon_start + 1
    end
    if entry.icon_hl_group ~= nil then
      local icon_opts = { hl_group = entry.icon_hl_group, end_col = name_start - 1, right_gravity = false }
      set_hl(i - 1, icon_start, icon_opts)
    end
    local name_opts = { hl_group = hl_group, end_row = i, end_col = 0, right_gravity = false }
    set_hl(i - 1, name_start - 1, name_opts)
  end
end

---@param win_id integer
---@param ns integer
---@param color string
function M.set_modified_winsep(win_id, ns, color)
  vim.wo[win_id].fillchars = "vert:┃,horiz:━,horizup:┻,horizdown:┳,vertleft:┫,vertright:┣,verthoriz:╋"
  vim.api.nvim_win_set_hl_ns(win_id, ns)
  vim.api.nvim_set_hl(M.ns_id.center_window, "WinSeparator", { fg = color })
end

return M
