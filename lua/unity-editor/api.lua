---@class UnityEditor.api
local M = {}

local cl = require("unity-editor.ipc.client")

--- Request Unity Editor to do something.
---@param project_dir string? Unity project directory path
---@param fn function(client: Client) function to request Unity Editor
local function request(project_dir, fn)
  -- if project_dir is not specified, find project root from current buffer
  if not project_dir then
    project_dir = M.find_project_root(vim.api.nvim_get_current_buf())
  end

  -- if project_dir is still not found, exit
  if not project_dir then
    vim.notify("Current buffer is not in Unity project", vim.log.levels.WARN)
    return
  end

  -- if project is not open in Unity Editor, exit
  if not M.is_project_open_in_unity(project_dir) then
    vim.notify("This project is not open in Unity Editor", vim.log.levels.WARN)
    return
  end

  local client = cl.get_project_client(project_dir)
  fn(client)
end

--- refresh Unity Editor asset database
--- this will compile scripts and refresh asset database
--- It works like focus on Unity Editor or press Ctrl+R
--- @param project_dir? string Unity project directory path
function M.refresh(project_dir)
  request(project_dir, function(client)
    client:request_refresh()
  end)
end

--- request Unity Editor to play game
---@param project_dir? string Unity project directory path
function M.playmode_enter(project_dir)
  request(project_dir, function(client)
    client:request_playmode_enter()
  end)
end

--- request Unity Editor to stop game
--- @param project_dir? string Unity project directory path
function M.playmode_exit(project_dir)
  request(project_dir, function(client)
    client:request_playmode_exit()
  end)
end

--- request Unity Editor to toggle play game
---@param project_dir? string Unity project directory path
function M.playmode_toggle(project_dir)
  request(project_dir, function(client)
    client:request_playmode_toggle()
  end)
end

--- generate Visual Studio solution files
---@param project_dir? string Unity project directory path
function M.generate_sln(project_dir)
  request(project_dir, function(client)
    client:request_generate_sln()
  end)
end

--- Check if the specified project is open in Unity Editor.
---@param project_root string Unity project root directory path
---@return boolean is_unity_editor_running
function M.is_project_open_in_unity(project_root)
  local editor_instance = vim.fs.joinpath(project_root, "Library/EditorInstance.json")
  return vim.uv.fs_access(editor_instance, "R") == true
end

--- Find Unity project root directory path.
---@param bufnr integer buffer number
---@return string|nil project_root Unity project root directory path
function M.find_project_root(bufnr)
  -- check `Assets` directory
  -- see https://docs.unity3d.com/Manual/SpecialFolders.html#Assets
  local buf = vim.api.nvim_buf_get_name(bufnr)
  local found = vim.fs.find("Assets", {
    upward = true,
    type = "directory",
    stop = vim.uv.os_homedir(),
    path = vim.fs.dirname(buf),
  })

  if vim.tbl_isempty(found) then
    return nil
  end

  local project_root = vim.fs.dirname(found[1])
  return project_root
end

M.autorefresh = require("unity-editor.autorefresh")

return M
