local M = {}

function M.setup()
  vim.api.nvim_create_user_command("UnityRefresh", function()
    require("unity-editor.api").refresh()
  end, { desc = "[Unity] Refresh asset database" })

  vim.api.nvim_create_user_command("UnityPlaymodeEnter", function()
    require("unity-editor.api").playmode_enter()
  end, { desc = "[Unity] Enter play mode" })

  vim.api.nvim_create_user_command("UnityPlaymodeExit", function()
    require("unity-editor.api").playmode_exit()
  end, { desc = "[Unity] Exit play mode" })

  vim.api.nvim_create_user_command("UnityPlaymodeToggle", function()
    require("unity-editor.api").playmode_toggle()
  end, { desc = "[Unity] Toggle play mode" })

  vim.api.nvim_create_user_command("UnityGenerateSln", function()
    require("unity-editor.api").generate_sln()
  end, { desc = "[Unity] Generate Visual Studio solution files" })

  vim.api.nvim_create_user_command("UnityAutoRefreshToggle", function()
    require("unity-editor.autorefresh").toggle()
  end, { desc = "[Unity] Toggle auto-refresh" })

  vim.api.nvim_create_user_command("UnityAutoRefreshEnable", function()
    require("unity-editor.autorefresh").enable()
  end, { desc = "[Unity] Enable auto-refresh" })

  vim.api.nvim_create_user_command("UnityAutoRefreshDisable", function()
    require("unity-editor.autorefresh").disable()
  end, { desc = "[Unity] Disable auto-refresh" })
end

return M
