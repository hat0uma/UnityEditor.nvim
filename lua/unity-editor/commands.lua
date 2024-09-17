local M = {}

function M.setup()
  local api = require("unity-editor.api")
  local commands = {
    refresh = api.refresh,
    generate_sln = api.generate_sln,
    playmode = {
      enter = api.playmode_enter,
      exit = api.playmode_exit,
      toggle = api.playmode_toggle,
    },
    autorefresh = {
      toggle = api.autorefresh.toggle,
      enable = api.autorefresh.enable,
      disable = api.autorefresh.disable,
    },
  }

  -- Create a command to manage Unity Editor
  vim.api.nvim_create_user_command("Unity", function(opts)
    local parts = vim.split(opts.args, " ", { trimempty = true })
    if #parts == 0 then
      return
    end

    local command_name = parts[1]
    local sub_command = commands[command_name]
    if not sub_command then
      vim.notify("Unknown subcommand: " .. command_name)
      return
    end

    if type(sub_command) == "function" then
      sub_command()
      return
    end

    local action = parts[2]
    if not action then
      vim.notify("Please specify an action: " .. table.concat(vim.tbl_keys(sub_command), ", "))
      return
    end

    if not sub_command[action] then
      vim.notify("Unknown action: " .. action)
      return
    end

    sub_command[action]()
  end, {
    desc = "[Unity] Manage Unity Editor",
    nargs = "?",
    complete = function(arg_lead, cmd_line, cursor_pos)
      -- "Unity   aa"
      --   - arg_lead = "aa"
      --   - cmd_line = "Unity   aa"
      --   - cursor_pos = 10
      local parts = vim.split(cmd_line, " ", { trimempty = true })
      if #parts == 1 then
        return vim.tbl_keys(commands)
      end

      -- subcommand completion
      local command_name = parts[2]
      if not commands[command_name] then
        return {}
      end

      local sub_command = commands[command_name]
      if type(sub_command) == "function" then
        return {}
      end

      if #parts == 3 then
        return {}
      end

      -- action completion
      return vim.tbl_keys(sub_command)
    end,
  })
end

return M
