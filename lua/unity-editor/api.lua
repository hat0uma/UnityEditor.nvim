local M = {}

local Editor = require("unity-editor.editor").Editor

--- @type table<string,UnityEditorClient>
local editors = {}

--- connect to Unity Editor
---@param project_dir string? Unity project directory path. If nil, use current working directory.
function M.connect(project_dir)
  if not project_dir then
    project_dir = vim.fn.getcwd()
  end

  -- check if already connected
  local editor = editors[project_dir]
  if editor and editor:is_connected() then
    vim.notify("already connected")
    return
  end

  -- create Unity Editor client and connect
  editor = Editor:new(project_dir)
  editor:connect()
  editors[project_dir] = editor
end

--- disconnect from Unity Editor
---@param project_dir string? Unity project directory path. If nil, use current working directory.
function M.disconnect(project_dir)
  if not project_dir then
    project_dir = vim.fn.getcwd()
  end

  local editor = editors[project_dir]
  if not editor then
    vim.notify("not connected")
    return
  end

  editor:close()
  editors[project_dir] = nil
end

--- request Unity Editor to compile project
---@param project_dir string? Unity project directory path. If nil, use current working directory.
function M.request_compile(project_dir)
  if not project_dir then
    project_dir = vim.fn.getcwd()
  end

  local editor = editors[project_dir]
  if not editor or not editor:is_connected() then
    vim.notify("not connected")
    return
  end

  editor:execute_method("UnityEditor.AssetDatabase", "Refresh", {})
  -- editor:execute_method("UnityEditor.Compilation.CompilationPipeline", "RequestScriptCompilation", {})
end

--- request Unity Editor to play game
---@param project_dir string? Unity project directory path. If nil, use current working directory.
function M.game_play(project_dir)
  if not project_dir then
    project_dir = vim.fn.getcwd()
  end

  local editor = editors[project_dir]
  if not editor or not editor:is_connected() then
    vim.notify("not connected")
    return
  end

  editor:execute_method("UnityEditor.EditorApplication", "EnterPlaymode", {})
end

--- request Unity Editor to pause game
--- @param project_dir string? Unity project directory path. If nil, use current working directory.
function M.game_pause(project_dir)
  if not project_dir then
    project_dir = vim.fn.getcwd()
  end

  local editor = editors[project_dir]
  if not editor or not editor:is_connected() then
    vim.notify("not connected")
    return
  end

  editor:execute_method("Debug", "Break", {})
end

--- request Unity Editor to stop game
---@param project_dir string? Unity project directory path. If nil, use current working directory.
function M.game_stop(project_dir)
  if not project_dir then
    project_dir = vim.fn.getcwd()
  end

  local editor = editors[project_dir]
  if not editor or not editor:is_connected() then
    vim.notify("not connected")
    return
  end

  editor:execute_method("UnityEditor.EditorApplication", "ExitPlaymode", {})
end

--- generate Visual Studio solution file
---@param project_dir string? Unity project directory path. If nil, use current working directory.
function M.generate_sln(project_dir)
  if not project_dir then
    project_dir = vim.fn.getcwd()
  end

  local editor = editors[project_dir]
  if not editor or not editor:is_connected() then
    vim.notify("not connected")
    return
  end

  -- this method is internal and may be removed in future.
  editor:execute_method("UnityEditor.SyncVS", "SyncSolution", {})
end

return M
