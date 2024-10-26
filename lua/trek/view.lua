local utils = require("trek.utils")
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

---@param win_id integer
function M.set_window_opts(win_id)
  vim.api.nvim_win_set_option(win_id, "number", false)
  vim.api.nvim_win_set_option(win_id, "relativenumber", false)
  vim.api.nvim_win_call(win_id, function()
    vim.fn.matchadd("Conceal", [[^/\d\+/]])
  end)
  vim.wo[win_id].cursorline = true
  vim.wo[win_id].conceallevel = 3
  vim.wo[win_id].concealcursor = "nvic"
  vim.wo[win_id].foldenable = false
  vim.wo[win_id].wrap = false
end

---@param entries trek.DirectoryEntry[]
---@param buf_id integer
function M.render_dir(entries, buf_id)
  local lines = utils.map(
    entries,
    ---@param entry trek.DirectoryEntry
    function(entry)
      local icon = M.get_icon(entry)
      return "/" .. entry.id .. "/" .. icon .. " " .. entry.name
    end
  )
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

return M
