local M = {
  ns_id = {
    highlight = vim.api.nvim_create_namespace("MiniFilesHighlight"),
  },
}

function M.set_extmark(...)
  pcall(vim.api.nvim_buf_set_extmark, ...)
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
  for i, entry in ipairs(entries) do
    local hl_group = entry.fs_type == "file" and "MiniFilesFile" or "MiniFilesDirectory"
    local line = lines[i]
    local icon_start, name_start = line:match("^/%d+/().-()/")
    if entry.icon_hl_group ~= nil then
      local icon_opts = { hl_group = entry.icon_hl_group, end_col = name_start - 1, right_gravity = false }
      set_hl(i - 1, icon_start - 1, icon_opts)
    end
    local name_opts = { hl_group = hl_group, end_row = i, end_col = 0, right_gravity = false }
    set_hl(i - 1, name_start - 1, name_opts)
  end
end

return M
