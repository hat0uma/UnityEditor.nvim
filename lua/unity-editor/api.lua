local M = {}

local Editor = require("unity-editor.editor").Editor

--- @type table<string,UnityEditorClient>
local editors = {}

--- get Unity Editor client instance
---@param project_dir string Unity project directory path
---@return UnityEditorClient
local function get_project_client(project_dir)
  local editor = editors[project_dir]
  if not editor then
    editor = Editor:new(project_dir)
    editors[project_dir] = editor
  end
  return editor
end

--- execute Unity Editor command
---@param type string
---@param arguments string[]
---@return fun(project_dir?: string)
local function unity_message_sender(type, arguments)
  ---@param project_dir? string
  return function(project_dir)
    if not project_dir then
      project_dir = assert(vim.uv.cwd())
    end

    -- execute unity-side method.
    local editor = get_project_client(project_dir)
    editor:send(type, arguments)
  end
end

--- refresh Unity Editor asset database
--- this will compile scripts and refresh asset database
--- It works like focus on Unity Editor or press Ctrl+R
M.refresh = unity_message_sender("refresh", {})

--- request Unity Editor to play game
M.playmode_enter = unity_message_sender("playmode_enter", {})

--- request Unity Editor to stop game
M.playmode_exit = unity_message_sender("playmode_exit", {})

--- generate Visual Studio solution file
M.generate_sln = unity_message_sender("generate_sln", {})

return M
