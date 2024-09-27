local M = {}

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

--- get subcommand completions
---@param lead string
---@return string[]
local function subcommand_candidates(lead)
  ---@diagnostic disable-next-line: no-unknown
  return vim.tbl_filter(function(v)
    return vim.startswith(v, lead)
  end, vim.tbl_keys(commands))
end

--- get action completions
---@param subcommand_name string
---@param lead string
---@return string[]
local function action_candidates(subcommand_name, lead)
  local subcommand = commands[subcommand_name]
  if type(subcommand) ~= "table" then
    return {}
  end

  ---@diagnostic disable-next-line: no-unknown
  return vim.tbl_filter(function(v)
    return vim.startswith(v, lead)
  end, vim.tbl_keys(subcommand))
end

function M.setup()
  -- Create a command to manage Unity Editor
  vim.api.nvim_create_user_command("Unity", function(opts)
    local parts = vim.split(opts.args, " ", { trimempty = true })
    if #parts == 0 then
      vim.notify("Please specify: " .. table.concat(vim.tbl_keys(commands), ", "))
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
      vim.notify("Please specify: " .. table.concat(vim.tbl_keys(sub_command), ", "))
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
      -- "Unity   aa|" (| is cursor position)
      --   - arg_lead = "aa"
      --   - cmd_line = "Unity   aa"
      --   - cursor_pos = 10
      -- print(arg_lead, cmd_line, cursor_pos)
      local parts = vim.split(cmd_line, "%s+", { trimempty = false })
      if #parts == 2 then
        return subcommand_candidates(parts[2])
      elseif #parts == 3 then
        return action_candidates(parts[2], parts[3])
      else
        return {}
      end
    end,
  })
end

return M
