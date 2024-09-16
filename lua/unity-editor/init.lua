--- @class UnityEditor.api
local M = {}

---Setup
---@param opts? UnityEditor.Config
function M.setup(opts)
  -- setup commands
  require("unity-editor.commands").setup()

  -- setup config
  local config = require("unity-editor.config")
  opts = config.setup(opts)

  -- enable auto-refresh
  if opts.autorefresh then
    require("unity-editor.autorefresh").enable()
  end
end

return setmetatable(M, {
  __index = function(_, k)
    return require("unity-editor.api")[k]
  end,
})
