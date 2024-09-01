vim.api.nvim_create_user_command("UnityRefresh", function()
  require("unity-editor.api").refresh()
end, {})

vim.api.nvim_create_user_command("UnityGamePlay", function()
  require("unity-editor.api").game_play()
end, {})

vim.api.nvim_create_user_command("UnityGameStop", function()
  require("unity-editor.api").game_stop()
end, {})

vim.api.nvim_create_user_command("UnityGenerateSln", function()
  require("unity-editor.api").generate_sln()
end, {})
