local M = {}

local api = require("unity-editor.api")

local cb = function(fn)
  return function()
    return fn()
  end
end

function M.setup()
  -- provide commands
  vim.api.nvim_create_user_command("UnityConnect", cb(api.connect), {})
  vim.api.nvim_create_user_command("UnityDisconnect", cb(api.disconnect), {})
  vim.api.nvim_create_user_command("UnityRequestCompile", cb(api.request_compile), {})
  vim.api.nvim_create_user_command("UnityGamePlay", cb(api.game_play), {})
  vim.api.nvim_create_user_command("UnityGamePause", cb(api.game_pause), {})
  vim.api.nvim_create_user_command("UnityGameStop", cb(api.game_stop), {})
  vim.api.nvim_create_user_command("UnityGenerateSln", cb(api.generate_sln), {})
end

return M
