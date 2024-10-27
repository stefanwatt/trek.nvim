-- main module file
local fs = require("trek.fs")
local explorer = require("trek.explorer")
local config = require("trek.config")

---@class Trek
local M = {}

---@type trek.Config
M.config = config.get_config()

---@param args trek.Config?
-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

---@param path string
M.open = function(path)
  local dir = fs.get_directory_of_path(path)
  explorer.open(dir)
end

return M
