local fs = require("trek.fs")
local explorer = require("trek.explorer")
local window = require("trek.window")
local config = require("trek.config")

---@class Trek
local M = {}

---@param args trek.Config?
M.setup = function(args)
  local user_config = config.default_config
  user_config = vim.tbl_deep_extend("force", user_config, args or {})
  config.apply_config(user_config)
end

---@param path string
M.open = function(path)
  local dir = fs.get_directory_of_path(path)
  window.opened_from_path = path
  explorer.open(dir)
end

return M
