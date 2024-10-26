local M = {}

---@generic T
---@param list Array<`T`>
---@param cb function(value: `T`): `T`
function M.map(list, cb)
  local result = {}
  for _, value in ipairs(list) do
    table.insert(result, cb(value))
  end
  return result
end

return M
