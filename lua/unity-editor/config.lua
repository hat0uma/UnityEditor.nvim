local M = {}

---@class UnityEditor.Config
local defaults = {
  autorefresh = true,
}

---@type UnityEditor.Config
local options

--- Setup config
---@param opts? UnityEditor.Config
---@return UnityEditor.Config
function M.setup(opts)
  ---@type UnityEditor.Config
  options = vim.tbl_deep_extend("force", {}, defaults, opts or {})
  return options
end

--- Get config
---@param opts? UnityEditor.Config
---@return UnityEditor.Config
function M.get(opts)
  if not options then
    M.setup()
  end
  return vim.tbl_deep_extend("force", options, opts or {})
end

return M
