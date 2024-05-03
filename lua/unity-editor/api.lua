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

--- refresh Unity Editor asset database
--- this will compile scripts and refresh asset database
--- It works like focus on Unity Editor or press Ctrl+R
---@param project_dir string? Unity project directory path. If nil, use current working directory.
function M.refresh(project_dir)
  if not project_dir then
    project_dir = vim.fn.getcwd()
  end
  -- execute unity-side method.
  -- This performs the same operation as pressing Ctrl+R in Unity Editor.
  local editor = get_project_client(project_dir)
  editor:execute_method("UnityEditor.AssetDatabase", "Refresh", {})
end

--- request Unity Editor to play game
---@param project_dir string? Unity project directory path. If nil, use current working directory.
function M.game_play(project_dir)
  if not project_dir then
    project_dir = vim.fn.getcwd()
  end
  -- execute unity-side method.
  -- This method causes AppDomain reload by default.
  -- so the connection will be disconnected once.
  local editor = get_project_client(project_dir)
  editor:execute_method("UnityEditor.EditorApplication", "EnterPlaymode", {})
end

--- request Unity Editor to stop game
---@param project_dir string? Unity project directory path. If nil, use current working directory.
function M.game_stop(project_dir)
  if not project_dir then
    project_dir = vim.fn.getcwd()
  end
  -- execute unity-side method.
  local editor = get_project_client(project_dir)
  editor:execute_method("UnityEditor.EditorApplication", "ExitPlaymode", {})
end

--- generate Visual Studio solution file
---@param project_dir string? Unity project directory path. If nil, use current working directory.
function M.generate_sln(project_dir)
  if not project_dir then
    project_dir = vim.fn.getcwd()
  end
  -- execute unity-side method.
  -- This method is internal and may be removed in future.
  local editor = get_project_client(project_dir)
  editor:execute_method("UnityEditor.SyncVS", "SyncSolution", {})
end

return M
