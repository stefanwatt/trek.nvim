-- main module file
local fs = require("trek.fs")
local explorer = require("trek.explorer")

---@class Config
---@field opt string Your config option
local config = {
  opt = "Hello!",
}

---@class Trek
local M = {}

---@type Config
M.config = config

---@param args Config?
-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

M.open = function()
  local path = vim.fn.getcwd(0,0)
  local dir = fs.get_dir_content(path)
  explorer.open(dir)
end

return M
