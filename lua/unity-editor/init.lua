local M = {}

local api = require("unity-editor.api")

function M.setup()
  -- provide commands
  vim.api.nvim_create_user_command("UnityRefresh", function()
    api.refresh()
  end, {})
  vim.api.nvim_create_user_command("UnityGamePlay", function()
    api.game_play()
  end, {})
  vim.api.nvim_create_user_command("UnityGameStop", function()
    api.game_stop()
  end, {})
  vim.api.nvim_create_user_command("UnityGenerateSln", function()
    api.generate_sln()
  end, {})
end

return M
