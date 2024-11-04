local fs = require("trek.fs")
local utils = require("trek.utils")
local explorer = require("trek.explorer")
local window = require("trek.window")
local config = require("trek.config")

---@class Trek
local M = {}

---@param args trek.Config?
M.setup = function(args)
  local user_config = config.default_config
  user_config = vim.tbl_deep_extend("force", user_config, args or {})
  user_config = config.validate_config(user_config)
  config.apply_config(user_config)
  if user_config.use_as_default_explorer then
    vim.api.nvim_create_autocmd('BufEnter', {
      group = utils.augroup("default_file_explorer"),
      pattern = "*",
      callback = function(event_args)
        fs.track_dir_edit(event_args.buf, explorer.open)
      end,
      desc = "Track directory edit",
    })
    vim.cmd('silent! autocmd! FileExplorer *')
    vim.cmd('autocmd VimEnter * ++once silent! autocmd! FileExplorer *')
  end
end

---@param path string
M.open = function(path)
  assert(path ~= nil and type(path) == "string", "path is not a string")
  local dir_path = fs.get_directory_of_path(path)
  explorer.open(dir_path)
end

return M
