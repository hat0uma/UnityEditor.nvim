local M = {}

local api = require("unity-editor.api")

local cb = function(fn)
  return function()
    return fn()
  end
end

function M.setup()
  -- provide commands
  vim.api.nvim_create_user_command("UnityRefresh", cb(api.refresh), {})
  vim.api.nvim_create_user_command("UnityGamePlay", cb(api.game_play), {})
  vim.api.nvim_create_user_command("UnityGameStop", cb(api.game_stop), {})
  vim.api.nvim_create_user_command("UnityGenerateSln", cb(api.generate_sln), {})
end

return M
