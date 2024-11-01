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
  },
  --TODO use_as_default_explorer = true,
  windows = {
    preview_width_percent = 50,
  },
  confirm_fs_actions = false,
  permanent_delete = true,
}

M.default_config = vim.deepcopy(M.config)

function M.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, "table", true } })
  config = vim.tbl_deep_extend("force", vim.deepcopy(M.default_config), config or {})

  vim.validate({
    mappings = { config.keymaps, "table" },
    options = { config.options, "table" },
  })

  vim.validate({
    ["keymaps.close"] = { config.keymaps.close, "string" },
    ["keymaps.go_in"] = { config.keymaps.go_in, "string" },
    ["keymaps.go_out"] = { config.keymaps.go_out, "string" },
    ["keymaps.synchronize"] = { config.keymaps.synchronize, "string" },

    -- ["options.use_as_default_explorer"] = { config.options.use_as_default_explorer, "boolean" },
    -- ["options.permanent_delete"] = { config.options.permanent_delete, "boolean" },
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
