local StreamReader = require("unity-editor.stream_reader")
local protocol = require("unity-editor.ipc.protocol")
local is_windows = vim.uv.os_uname().sysname:match("Windows")

local PIPENAME_BASE = is_windows and "\\\\.\\pipe\\UnityEditorIPC" or "/tmp/UnityEditorIPC"

---@class UnityEditor.EditorInstance
---@field process_id number
---@field version string
---@field app_path string
---@field app_contents_path string

--- @class UnityEditor.Client
--- @field _pipe uv_pipe_t
--- @field _project_dir string
local Client = {}

--- Create new Unity Editor client
---@param project_dir string Unity project directory path
---@return UnityEditor.Client
function Client:new(project_dir)
  local obj = {}
  obj._pipe = vim.uv.new_pipe(false)
  obj._project_dir = project_dir

  setmetatable(obj, self)
  self.__index = self
  return obj
end

--- @async
--- Connect to Unity Editor
--- If already connected, do nothing.
--- @return boolean, string?
function Client:connect_async()
  if self:is_connected() then
    return true
  end

  -- load EditorInstance.json
  local editor_instance = self:_load_editor_instance_json()
  local pipename = self:_pipename(editor_instance)

  -- connect to Unity Editor
  print("Connecting to Unity Editor: " .. pipename)
  local thread = coroutine.running()
  self._pipe = vim.uv.new_pipe(false)
  self._pipe:connect(pipename, function(err)
    coroutine.resume(thread, err)
  end)

  --- @type string?
  local err = coroutine.yield()
  if err then
    return false, err
  end

  print("Connected to Unity Editor")
  return true
end

--- Close connection to Unity Editor
function Client:close()
  pcall(self._pipe.close, self._pipe)
end

--- Check if connected to Unity Editor
---@return boolean
function Client:is_connected()
  if not self._pipe then
    return false
  end

  return self._pipe:getpeername() ~= nil
end

--- refresh Unity Editor asset database
--- this will compile scripts and refresh asset database
--- It works like focus on Unity Editor or press Ctrl+R
function Client:request_refresh()
  self:_request("refresh", {})
end

--- request Unity Editor to play game
function Client:request_playmode_enter()
  self:_request("playmode_enter", {})
end

--- request Unity Editor to stop game
function Client:request_playmode_exit()
  self:_request("playmode_exit", {})
end

--- request Unity Editor to toggle play game
function Client:request_playmode_toggle()
  self:_request("playmode_toggle", {})
end

--- generate Visual Studio solution file
function Client:request_generate_sln()
  self:_request("generate_sln", {})
end

--------------------------------------
-- private methods
--------------------------------------

--- Get pipename for Unity Editor
---@param editor_instance UnityEditor.EditorInstance
---@return string
function Client:_pipename(editor_instance)
  return string.format("%s-%d", PIPENAME_BASE, editor_instance.process_id)
end

--- Load EditorInstance.json
---@return UnityEditor.EditorInstance
function Client:_load_editor_instance_json()
  local json_path = vim.fs.joinpath(self._project_dir, "Library/EditorInstance.json")

  -- open EditorInstance.json
  local f, err = vim.uv.fs_open(json_path, "r", 438)
  if not f then
    error(string.format("%s open failed.", json_path))
  end

  -- get file size
  local stat, err = vim.uv.fs_fstat(f)
  if not stat then
    vim.uv.fs_close(f)
    error(string.format("%s stat failed.", json_path))
  end

  -- read file
  local data, err = vim.uv.fs_read(f, stat.size, 0)
  vim.uv.fs_close(f)
  if type(data) ~= "string" then
    error(string.format("%s read failed.", json_path))
  end

  -- decode json
  local json = vim.json.decode(data)
  if type(json) ~= "table" then
    error(string.format("%s decode failed.", json_path))
  end

  --  json must have process_id,version,app_path,app_contents_path
  vim.validate({
    process_id = { json.process_id, "number" },
    version = { json.version, "string" },
    app_path = { json.app_path, "string" },
    app_contents_path = { json.app_contents_path, "string" },
  })

  return json
end

--- Handle response from Unity Editor
---@param data? UnityEditor.ResponseMessage
---@param err? string
function Client:_handle_response(data, err)
  if not data then
    vim.notify(assert(err), vim.log.levels.ERROR)
    return
  end

  if data.status ~= protocol.Status.OK then
    vim.notify(data.result, vim.log.levels.WARN)
  end
end

--- Request to Unity Editor
---@param method string
---@param parameters string[]
---@param callback? fun(data?: UnityEditor.ResponseMessage, err?: string)
function Client:_request(method, parameters, callback)
  -- response handler
  callback = callback or function(data, err)
    self:_handle_response(data, err)
  end

  local thread
  thread = coroutine.create(function() --- @async
    -- connect to Unity Editor
    local ok, err = self:connect_async()
    if not ok then
      callback(nil, string.format("Failed to connect to Unity Editor: %s", err or ""))
      return
    end

    -- send request
    local message = protocol.serialize_request(method, parameters)
    self._pipe:write(message, function(err)
      coroutine.resume(thread, err)
    end)

    -- wait for write completion
    local err = coroutine.yield() --- @type string?
    if err then
      callback(nil, string.format("Failed to write to Unity Editor: %s", err or ""))
      return
    end

    -- read response
    local reader = StreamReader:new(self._pipe, thread)
    local data, err = reader:readline_async()
    reader:close()
    if not data then
      callback(nil, string.format("Failed to read from Unity Editor: %s", err or ""))
      return
    end

    -- decode response
    local ok, response = pcall(protocol.deserialize_response, data)
    if not ok then
      callback(string.format("Failed to decode response: %s", response or ""))
      return
    end

    -- handle response
    callback(response)
  end)

  -- start connection coroutine
  local ok, err = coroutine.resume(thread)
  if not ok then
    vim.notify(string.format("Failed to start connection coroutine: %s", err or ""))
  end
end

--------------------------------------
-- module exports
--------------------------------------

local M = {}
M.Client = Client

--- @type table<string,UnityEditor.Client>
local clients = {}

--- get Unity Editor client instance
---@param project_dir string Unity project directory path
---@return UnityEditor.Client
function M.get_project_client(project_dir)
  -- normalize project_dir
  project_dir = assert(vim.uv.fs_realpath(project_dir))

  local client = clients[project_dir]
  if not client then
    client = Client:new(project_dir)
    clients[project_dir] = client
  end
  return client
end

return M
