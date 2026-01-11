local StreamReader = require("unity-editor.stream_reader")
local log = require("unity-editor.log")
local protocol = require("unity-editor.protocol")
local util = require("unity-editor.util")
local is_windows = vim.uv.os_uname().sysname:match("Windows")

local PIPENAME_BASE = is_windows and "\\\\.\\pipe\\UnityEditorIPC" or "/tmp/UnityEditorIPC"

local next_request_id = (function()
  local id = 0
  return function()
    id = id + 1
    return id
  end
end)()

--- Print response from Unity Editor
---@param data? UnityEditor.ResponseMessage
---@param err? string
local print_response = vim.schedule_wrap(function(data, err)
  if not data then
    log.error("Failed to request Unity Editor: %s", err or "")
    return
  end

  if data.status == protocol.Status.OK then
    log.info(data.result)
  else
    log.warn(data.result)
  end
end)

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
---@param parameters table|nil
---@param callback? fun(data?: UnityEditor.ResponseMessage, err?: string)
function Client:request(method, parameters, callback)
  callback = callback or print_response

  if self._requesting then
    log.warn("Request is already in progress")
    return
  end

  -- Start coroutine
  local thread = coroutine.create(function()
    self._requesting = true
    self:_notify_request_state_changed("started", method)
    local ok, res_or_err = pcall(self._execute_request, self, method, parameters)
    self:_notify_request_state_changed("finished", method)
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
    log.error("Failed to start connection coroutine: %s", err or "")
  end
end

--------------------------------------
-- private methods
--------------------------------------

--- Notify requst state changed
---@param state "started" | "finished"
---@param method string
function Client:_notify_request_state_changed(state, method)
  local pattern = state == "started" and "UnityEditorRequestStarted" or "UnityEditorRequestFinished"
  vim.schedule(function()
    vim.api.nvim_exec_autocmds("User", {
      pattern = pattern,
      data = { project_dir = self._project_dir, method = method },
    })
  end)
end

--- @async
--- Connect to Unity Editor
--- If already connected, do nothing.
--- @return boolean, string?
function Client:_connect_async()
  local thread = coroutine.running()
  if self:is_connected() then
    return true
  end

  -- Load EditorInstance.json for decide pipename
  local ok, editor_instance = pcall(util.load_editor_instance_json, self._project_dir)
  if not ok and type(editor_instance) == "string" then
    return false, editor_instance
  end

  -- Close old pipe
  if self._pipe then
    self:_close()
  end

  -- Create pipe
  local pipename = self:_pipename(editor_instance)
  local pipe, pipe_err = vim.uv.new_pipe(false)
  if not pipe then
    return false, pipe_err
  end

  -- Connect to Unity Editor
  log.debug("Connecting to Unity Editor: %s", pipename)
  self._pipe = pipe

  local timer = assert(vim.uv.new_timer())
  local is_resolved = false
  timer:start(2000, 0, function()
    if is_resolved then
      return
    end
    is_resolved = true

    timer:close()
    if not self._pipe:is_closing() then
      self._pipe:close()
    end
    coroutine.resume(thread, "ETIMEDOUT")
  end)

  self._pipe:connect(pipename, function(err)
    if is_resolved then
      return
    end
    is_resolved = true

    timer:stop()
    timer:close()
    coroutine.resume(thread, err)
  end)

  -- Wait for connect
  local conn_err = coroutine.yield()
  if conn_err then
    return false, conn_err
  end

  log.debug("Connected to Unity Editor")
  return true
end

--- Close connection to Unity Editor
function Client:_close()
  pcall(self._pipe.close, self._pipe)
end

--- Get pipename for Unity Editor
---@param editor_instance UnityEditor.EditorInstance
---@return string
function Client:_pipename(editor_instance)
  return string.format("%s-%d", PIPENAME_BASE, editor_instance.process_id)
end

---@async
--- Execute request
---@param method string
---@param parameters table|nil
---@return UnityEditor.ResponseMessage? response
function Client:_execute_request(method, parameters)
  local opts = { write_max_retries = 10, read_max_retries = 10, retry_interval_ms = 500, readline_timeout_ms = 500 }

  -- Serialize request
  local request_id = next_request_id()
  local message = protocol.serialize_request(method, parameters, request_id)

  -- Connect to Unity Editor
  local ok, err
  ok, err = self:_connect_async()
  if not ok then
    error(string.format("Failed to connect to Unity Editor: %s", err or ""))
  end

  -- Send request
  ok = util.run_with_retry("Write", opts.write_max_retries, opts.retry_interval_ms, function() ---@async
    local _, wr_err = self._pipe:write(message)
    if wr_err then
      self:_close()
      self:_connect_async()
    end
    return wr_err
  end)

  if not ok then
    self:_close()
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
    self:_close()
    error("Read Max Retries Exceeded")
  end

  return response
end

--- @async
--- Read response from Unity Editor
---@param request_id integer
---@param timeout_ms integer
---@return UnityEditor.ResponseMessage? response, string? err
function Client:_read_response(request_id, timeout_ms)
  local thread = coroutine.running()
  local reader = StreamReader:new(self._pipe, thread)

  -- Read header (8 bytes)
  local header, header_err = reader:read_async(protocol.HEADER_SIZE, timeout_ms)
  if not header then
    if header_err ~= "timeout" then
      self:_close()
      self:_connect_async()
    end
    return nil, header_err
  end

  -- Parse header
  local payload_length, parse_err = protocol.deserialize_header(header)
  if not payload_length then
    return nil, parse_err
  end

  -- Read payload
  local payload, payload_err = reader:read_async(payload_length, timeout_ms)
  if not payload then
    if payload_err ~= "timeout" then
      self:_close()
      self:_connect_async()
    end
    return nil, payload_err
  end

  -- Decode response
  local ok, response = pcall(protocol.deserialize_response, payload)
  if not ok then
    return nil, string.format("Failed to decode response: %s(%s)", response, payload or "")
  end

  -- Validate response id
  if response.id ~= request_id then
    return nil, string.format("Id mismatch: expected %d, got %d", request_id, response.id)
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
