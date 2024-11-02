local M = {}

---@class trek.LSPConfig
---@field timeout_ms integer
---@field autosave_changes boolean
---
---@class trek.KeymapsConfig
---@field close string
---@field go_in string
---@field go_out string
---@field synchronize string
---@field toggle_entry_marked string
---
---@class trek.Config
---@field keymaps trek.KeymapsConfig
---@field lsp trek.LSPConfig
M.config = {
  lsp = {
    timeout_ms = 500,
    autosave_changes = true,
  },
  keymaps = {
    close = "q",
    go_in = "<Right>",
    go_out = "<Left>",
    synchronize = "=",
    toggle_entry_marked = "<Tab>",
  },
  windows = {
    preview_width_percent = 50,
  },
  use_as_default_explorer = true,
  confirm_fs_actions = false,
  permanent_delete = true,
}

M.default_config = vim.deepcopy(M.config)

function M.validate_config(config)
  vim.validate({ config = { config, "table", true } })
  config = vim.tbl_deep_extend("force", vim.deepcopy(M.default_config), config or {})

  vim.validate({
    keymaps = { config.keymaps, "table" },
    lsp = { config.lsp, "table" },
    windows = { config.windows, "table" },
    use_as_default_explorer = { config.use_as_default_explorer, "boolean" },
    confirm_fs_actions = { config.confirm_fs_actions, "boolean" },
    permanent_delete = { config.permanent_delete, "boolean" },
  })

  vim.validate({
    ["keymaps.close"] = { config.keymaps.close, "string" },
    ["keymaps.go_in"] = { config.keymaps.go_in, "string" },
    ["keymaps.go_out"] = { config.keymaps.go_out, "string" },
    ["keymaps.synchronize"] = { config.keymaps.synchronize, "string" },
    ["keymaps.toggle_entry_marked"] = { config.keymaps.toggle_entry_marked, "string" },
    ["windows.preview_width_percent"] = { config.windows.preview_width_percent, "number" },
    ["lsp.timeout_ms"] = { config.lsp.timeout_ms, "number" },
    ["lsp.autosave_changes"] = { config.lsp.autosave_changes, "boolean" },
  })

  return config
end

function M.apply_config(config)
  M.config = config
end

--stylua: ignore
function M.get_config(config)
  return vim.tbl_deep_extend('force', M.config, vim.b.trek_config or {}, config or {})
end

return M
