--- @class UnityEditor.api
local M = {}

---Setup
---@param opts? UnityEditor.Config
function M.setup(opts)
  -- setup commands
  require("unity-editor.commands").setup()

  -- setup config
  opts = require("unity-editor.config").setup(opts)

  -- enable auto-refresh
  if opts.autorefresh then
    require("unity-editor.autorefresh").enable()
  end

  if Snacks and pcall(require, "snacks.picker") then
    Snacks.picker.sources.unity_logs = require("unity-editor.integrations.snacks").source
  end
end

return setmetatable(M, {
  __index = function(_, k)
    return require("unity-editor.api")[k]
  end,
})
