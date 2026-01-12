local Client = require("unity-editor.client")
local log = require("unity-editor.log")

---@class UnityEditor.api
local M = {}

--- @type table<string,UnityEditor.Client>
local clients = {}

--- Get client
---@param opts { project_dir?: string, bufnr?:integer }
---@return UnityEditor.Client? client, string? reason
function M.get_client(opts)
  -- if project_dir is not specified, find project root from buffer
  local project_dir = opts.project_dir
  if not project_dir then
    project_dir = M.find_project_root(opts.bufnr or vim.api.nvim_get_current_buf())
  end

  -- if project_dir is still not found, exit
  if not project_dir then
    return nil, "Current buffer is not in Unity project"
  end

  -- if project is not open in Unity Editor, exit
  if not M.is_project_open_in_unity(project_dir) then
    return nil, "This project is not open in Unity Editor"
  end

  local key = vim.fs.normalize(project_dir)
  local client = clients[key]
  if not client then
    client = Client:new(project_dir)
    clients[key] = client
  end

  return client
end

--- Request Unity Editor to do something.
---@param project_dir string? Unity project directory path
---@param method string
---@param parameters table|nil
---@param callback? fun(data?: UnityEditor.ResponseMessage, err?: string)
---@return boolean success Whether the request was initiated
local function request(project_dir, method, parameters, callback)
  local client, reason = M.get_client({ project_dir = project_dir })
  if not client then
    if reason then
      vim.notify(reason, vim.log.levels.WARN)
    end
    return false
  end

  client:request(method, parameters, callback)
  return true
end

--- refresh Unity Editor asset database
--- this will compile scripts and refresh asset database
--- It works like focus on Unity Editor or press Ctrl+R
--- @param project_dir? string Unity project directory path
function M.refresh(project_dir)
  request(project_dir, "refresh", {})
end

--- request Unity Editor to play game
---@param project_dir? string Unity project directory path
function M.playmode_enter(project_dir)
  request(project_dir, "playmode_enter", {})
end

--- request Unity Editor to stop game
--- @param project_dir? string Unity project directory path
function M.playmode_exit(project_dir)
  request(project_dir, "playmode_exit", {})
end

--- request Unity Editor to toggle play game
---@param project_dir? string Unity project directory path
function M.playmode_toggle(project_dir)
  request(project_dir, "playmode_toggle", {})
end

--- generate Visual Studio solution files
---@param project_dir? string Unity project directory path
function M.generate_sln(project_dir)
  request(project_dir, "generate_sln", {})
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

---@class UnityEditor.LogEntry
---@field file string
---@field line integer
---@field column integer
---@field message string
---@field details string
---@field severity "error" | "warning" | "info"

---@class UnityEditor.LogsResponse
---@field items UnityEditor.LogEntry[]

--- Send logs to quickfix
---@param response UnityEditor.LogsResponse
local function send_to_qflist(response)
  local severity_map = {
    ["error"] = "E",
    ["warning"] = "W",
    ["info"] = "I",
  }

  local qf_items = {} ---@type vim.quickfix.entry[]
  for _, item in ipairs(response.items or {}) do
    qf_items[#qf_items + 1] = {
      filename = item.file,
      lnum = item.line,
      col = item.column,
      text = item.message,
      type = severity_map[item.severity],
    }
  end

  vim.fn.setqflist({}, " ", { title = "Unity Log", items = qf_items })
  if #qf_items > 0 then
    vim.cmd("copen")
  else
    vim.notify("No logs found", vim.log.levels.INFO)
  end
end

--- Get logs from Unity Editor.
--- Uses snacks.picker if available, falls back to quickfix.
---@param project_dir? string Unity project directory path
---@param handler? fun( response:UnityEditor.LogsResponse )
function M.logs(project_dir, handler)
  handler = handler or send_to_qflist
  request(
    project_dir,
    "get_logs",
    nil,
    vim.schedule_wrap(function(response, err)
      if err then
        log.error(err)
        return
      end
      if not response then
        log.error("No response from Unity Editor")
        return
      end

      ---@type boolean, UnityEditor.LogsResponse
      local ok, logs = pcall(vim.json.decode, response.result)
      if not ok then
        log.error("Failed to parse logs: " .. response.result, vim.log.levels.ERROR)
        return
      end

      handler(logs)
    end)
  )
end

M.autorefresh = require("unity-editor.autorefresh")

return M
