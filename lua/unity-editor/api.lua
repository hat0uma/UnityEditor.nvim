---@class UnityEditor.api
local M = {}

local cl = require("unity-editor.client")

--- refresh Unity Editor asset database
--- this will compile scripts and refresh asset database
--- It works like focus on Unity Editor or press Ctrl+R
--- @param project_dir? string Unity project directory path
function M.refresh(project_dir)
  if not project_dir then
    project_dir = assert(vim.uv.cwd())
  end

  local client = cl.get_project_client(project_dir)
  client:request_refresh()
end

--- request Unity Editor to play game
---@param project_dir? string Unity project directory path
function M.playmode_enter(project_dir)
  if not project_dir then
    project_dir = assert(vim.uv.cwd())
  end

  local client = cl.get_project_client(project_dir)
  client:request_playmode_enter()
end

--- request Unity Editor to stop game
--- @param project_dir? string Unity project directory path
function M.playmode_exit(project_dir)
  if not project_dir then
    project_dir = assert(vim.uv.cwd())
  end

  local client = cl.get_project_client(project_dir)
  client:request_playmode_exit()
end

--- request Unity Editor to toggle play game
---@param project_dir? string Unity project directory path
function M.playmode_toggle(project_dir)
  if not project_dir then
    project_dir = assert(vim.uv.cwd())
  end

  local client = cl.get_project_client(project_dir)
  client:request_playmode_toggle()
end

--- generate Visual Studio solution files
---@param project_dir? string Unity project directory path
function M.generate_sln(project_dir)
  if not project_dir then
    project_dir = assert(vim.uv.cwd())
  end

  local client = cl.get_project_client(project_dir)
  client:request_generate_sln()
end

--- Find Unity project root directory path.
---@param bufnr integer buffer number
---@return string|nil project_root Unity project root directory path
function M.find_unity_project_root(bufnr)
  local buf = vim.api.nvim_buf_get_name(bufnr)
  local found = vim.fs.find("Library/EditorInstance.json", {
    upward = true,
    type = "file",
    stop = vim.uv.os_homedir(),
    path = vim.fs.dirname(buf),
  })

  if vim.tbl_isempty(found) then
    return nil
  end

  local project_root = vim.fs.dirname(vim.fs.dirname(found[1]))
  return project_root
end

M.autorefresh = require("unity-editor.autorefresh")

return M
