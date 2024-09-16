local M = {}

function M.setup()
  local api = require("unity-editor.api")
  local autorefresh = require("unity-editor.autorefresh")

  local commands = {
    { name = "UnityRefresh", fn = api.refresh, desc = "Refresh asset database" },
    { name = "UnityPlaymodeEnter", fn = api.playmode_enter, desc = "Enter play mode" },
    { name = "UnityPlaymodeExit", fn = api.playmode_exit, desc = "Exit play mode" },
    { name = "UnityPlaymodeToggle", fn = api.playmode_toggle, desc = "Toggle play mode" },
    { name = "UnityGenerateSln", fn = api.generate_sln, desc = "Generate Visual Studio solution files" },
    { name = "UnityAutoRefreshToggle", fn = autorefresh.toggle, desc = "Toggle auto-refresh" },
    { name = "UnityAutoRefreshEnable", fn = autorefresh.enable, desc = "Enable auto-refresh" },
    { name = "UnityAutoRefreshDisable", fn = autorefresh.disable, desc = "Disable auto-refresh" },
  }

  for _, cmd in ipairs(commands) do
    vim.api.nvim_create_user_command(cmd.name, function()
      cmd.fn()
    end, { desc = "[Unity] " .. cmd.desc })
  end
end

return M
