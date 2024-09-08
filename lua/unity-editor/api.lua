---@class UnityEditor.api
local M = {}

local Client = require("unity-editor.client").Client

--- @type table<string,UnityEditor.Client>
local clients = {}

--- get Unity Editor client instance
---@param project_dir string Unity project directory path
---@return UnityEditor.Client
local function get_project_client(project_dir)
  local client = clients[project_dir]
  if not client then
    client = Client:new(project_dir)
    clients[project_dir] = client
  end
  return client
end

--- execute Unity Editor command
---@param method string
---@param parameters string[]
---@return fun(project_dir?: string)
local function unity_message_sender(method, parameters)
  ---@param project_dir? string
  return function(project_dir)
    if not project_dir then
      project_dir = assert(vim.uv.cwd())
    end

    -- execute unity-side method.
    local client = get_project_client(project_dir)
    client:send({ method = method, parameters = parameters })
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

--- request Unity Editor to toggle play game
M.playmode_toggle = unity_message_sender("playmode_toggle", {})

--- generate Visual Studio solution file
M.generate_sln = unity_message_sender("generate_sln", {})

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

return M
