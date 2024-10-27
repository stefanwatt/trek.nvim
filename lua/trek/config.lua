local M = {}

M.config = {
  -- Customization of shown content
  lsp_file_methods = {
    timeout_ms = 500,
    autosave_changes = true,
  },
  -- Module mappings created only inside explorer.
  -- Use `''` (empty string) to not create one.
  keymaps = {
    close = "q",
    go_in = "<Right>",
    go_out = "<Left>",
    reset = "<BS>",
    reveal_cwd = "@",
    show_help = "?",
    synchronize = "=",
  },

  -- General options
  options = {
    -- Whether to delete permanently or move into module-specific trash
    permanent_delete = true,
    -- Whether to use for editing directories
    use_as_default_explorer = true,
    -- Whether to be prompted for confirmation when performing filesystem actions
    confirm_fs_actions = true,
  },

  -- Customization of explorer windows
  windows = {
    -- Maximum number of windows to show side by side
    max_number = 3,
    -- Whether to show preview of file/directory under cursor
    preview = true,
    width_focus = math.floor(vim.o.columns * 0.2),
    width_nofocus = math.floor(vim.o.columns * 0.2),
    width_preview = math.floor(vim.o.columns * 0.6),
  },
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
    windows = { config.windows, "table" },
  })

  vim.validate({
    ["mappings.close"] = { config.keymaps.close, "string" },
    ["mappings.go_in"] = { config.keymaps.go_in, "string" },
    ["mappings.go_out"] = { config.keymaps.go_out, "string" },
    ["mappings.reset"] = { config.keymaps.reset, "string" },
    ["mappings.reveal_cwd"] = { config.keymaps.reveal_cwd, "string" },
    ["mappings.show_help"] = { config.keymaps.show_help, "string" },
    ["mappings.synchronize"] = { config.keymaps.synchronize, "string" },

    ["options.use_as_default_explorer"] = { config.options.use_as_default_explorer, "boolean" },
    ["options.permanent_delete"] = { config.options.permanent_delete, "boolean" },

    ["windows.max_number"] = { config.windows.max_number, "number" },
    ["windows.preview"] = { config.windows.preview, "boolean" },
    ["windows.width_focus"] = { config.windows.width_focus, "number" },
    ["windows.width_nofocus"] = { config.windows.width_nofocus, "number" },
    ["windows.width_preview"] = { config.windows.width_preview, "number" },
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