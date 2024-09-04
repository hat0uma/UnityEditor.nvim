vim.api.nvim_create_user_command("UnityRefresh", function()
  require("unity-editor.api").refresh()
end, {})

vim.api.nvim_create_user_command("UnityPlaymodeEnter", function()
  require("unity-editor.api").playmode_enter()
end, {})

vim.api.nvim_create_user_command("UnityPlaymodeExit", function()
  require("unity-editor.api").playmode_exit()
end, {})

vim.api.nvim_create_user_command("UnityPlaymodeToggle", function()
  require("unity-editor.api").playmode_toggle()
end, {})

vim.api.nvim_create_user_command("UnityGenerateSln", function()
  require("unity-editor.api").generate_sln()
end, {})
