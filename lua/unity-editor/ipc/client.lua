local StreamReader = require("unity-editor.stream_reader")
local protocol = require("unity-editor.ipc.protocol")
local util = require("unity-editor.ipc.util")
local is_windows = vim.uv.os_uname().sysname:match("Windows")

local PIPENAME_BASE = is_windows and "\\\\.\\pipe\\UnityEditorIPC" or "/tmp/UnityEditorIPC"

local next_request_id = (function()
  local id = 0
  return function()
    id = id + 1
    return id
  end
end)()

--- @class UnityEditor.Client
--- @field _pipe uv.uv_pipe_t?
--- @field _project_dir string
--- @field _requesting boolean
local Client = {}

--- Create new Unity Editor client
---@param project_dir string Unity project directory path
---@return UnityEditor.Client
function Client:new(project_dir)
  local obj = {}

  obj._project_dir = project_dir
  obj._pipe = nil ---@type uv.uv_pipe_t?
  obj._requesting = false

  setmetatable(obj, self)
  self.__index = self
  return obj
end

--- @async
--- Connect to Unity Editor
--- If already connected, do nothing.
--- @return boolean, string?
function Client:connect_async()
  local thread = coroutine.running()
  if self:is_connected() then
    return true
  end

  -- Load EditorInstance.json for decide pipename
  local editor_instance = util.load_editor_instance_json(self._project_dir)
  local pipename = self:_pipename(editor_instance)

  -- Close old pipe
  if self._pipe then
    self:close()
  end

  -- Create pipe
  local pipe, pipe_err = vim.uv.new_pipe(false)
  if not pipe then
    return false, pipe_err
  end

  -- Connect to Unity Editor
  print("Connecting to Unity Editor: " .. pipename)
  self._pipe = pipe
  self._pipe:connect(pipename, function(err)
    coroutine.resume(thread, err)
  end)

  -- Wait for connect
  local conn_err = coroutine.yield()
  if conn_err then
    return false, conn_err
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

  return self._pipe:is_readable() and self._pipe:is_writable()
end

--- Request to Unity Editor
---@param method string
---@param parameters string[]
---@param callback? fun(data?: UnityEditor.ResponseMessage, err?: string)
function Client:request(method, parameters, callback)
  callback = callback or function(data, err)
    self:_print_response(data, err)
  end

  if self._requesting then
    vim.notify("Request is already in progress", vim.log.levels.WARN)
    return
  end

  -- Start coroutine
  local thread = coroutine.create(function()
    self._requesting = true
    local ok, res_or_err = pcall(self._execute_request, self, method, parameters)
    self._requesting = false
    if ok then
      callback(res_or_err, nil)
    else
      callback(nil, res_or_err)
    end
  end)

  -- start connection coroutine
  local ok, err = coroutine.resume(thread)
  if not ok then
    vim.notify(string.format("Failed to start connection coroutine: %s", err or ""))
  end
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

--- Handle response from Unity Editor
---@param data? UnityEditor.ResponseMessage
---@param err? string
function Client:_print_response(data, err)
  if not data then
    vim.notify(string.format("Failed to request Unity Editor: %s", err or ""), vim.log.levels.ERROR)
    return
  end

  if data.status == protocol.Status.OK then
    print(data.result)
  else
    vim.notify(data.result, vim.log.levels.WARN)
  end
end

---@async
--- Execute request
---@param method string
---@param parameters string[]
---@return UnityEditor.ResponseMessage? response
function Client:_execute_request(method, parameters)
  local opts = { write_max_retries = 10, read_max_retries = 10, retry_interval_ms = 500, readline_timeout_ms = 500 }

  -- Serialize request
  local request_id = next_request_id()
  local message = protocol.serialize_request(method, parameters, request_id)

  -- Connect to Unity Editor
  local ok, err
  ok, err = self:connect_async()
  if not ok then
    error(string.format("Failed to connect to Unity Editor: %s", err or ""))
  end

  -- Send request
  ok = util.run_with_retry("Write", opts.write_max_retries, opts.retry_interval_ms, function() ---@async
    local _, wr_err = self._pipe:write(message)
    if wr_err then
      self:close()
      self:connect_async()
    end
    return wr_err
  end)

  if not ok then
    self:close()
    error("Write Max Retries Exceeded")
  end

  -- Read response
  local response ---@type UnityEditor.ResponseMessage?
  util.run_with_retry("Read", opts.read_max_retries, opts.retry_interval_ms, function() ---@async
    local read_err
    response, read_err = self:_read_response(request_id, opts.readline_timeout_ms)
    return read_err
  end)

  if not response then
    self:close()
    error("Read Max Retries Exceeded")
  end

  return response
end

--- @async
--- Read response from Unity Editor
---@param request_id integer
---@param readline_timeout integer
---@return UnityEditor.ResponseMessage? response, string? err
function Client:_read_response(request_id, readline_timeout)
  local thread = coroutine.running()
  local reader = StreamReader:new(self._pipe, thread)
  local data, err = reader:readline_async(nil, readline_timeout)
  if not data then
    if err ~= "timeout" then
      self:close()
      self:connect_async()
    end
    return nil, err
  end

  -- decode response
  local ok, response = pcall(protocol.deserialize_response, data)
  if not ok then
    return nil, string.format("Failed to decode response: %s", data or "")
  end

  -- if response id is not matched, ignore and wait for next response
  if response.id ~= request_id then
    return nil, string.format("Id Not matched: requested %d but %d. (%s)", request_id, response.id, data or "")
  end

  return response, nil
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

--- get all clients
---@return table<string,UnityEditor.Client>
function M.get_clients()
  return clients
end

return M
