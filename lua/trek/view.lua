local utils = require("trek.utils")
local highlights = require("trek.highlights")

local M = {}

---@param path string
---@return string[]
function M.get_file_preview(path)
  return {}
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

---@param entries trek.DirectoryEntry[]
---@param buf_id integer
function M.render_dir(entries, buf_id)
  local lines = utils.map(
    entries,
    ---@param entry trek.DirectoryEntry
    function(entry)
      local icon = M.get_icon(entry)
      return "/" .. entry.id .. "/" .. icon .. " /" .. entry.name
    end
  )
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
  highlights.add_highlights(buf_id, entries)
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
