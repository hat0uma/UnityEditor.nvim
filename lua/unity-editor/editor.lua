local M = {}

local ipc = require("unity-editor.ipc")
local is_windows = vim.loop.os_uname().sysname:match("Windows")

local PIPENAME_BASE = is_windows and "\\\\.\\pipe\\UnityEditorIPC" or "/tmp/UnityEditorIPC"
local function set_interval(interval, callback)
  local timer = vim.loop.new_timer()
  timer:start(interval, interval, function()
    callback()
  end)
  return timer
end

local function clear_interval(timer)
  timer:stop()
  timer:close()
end

--- load Unity EditorInstance.json
---@param project_dir string Unity project directory path
---@return {process_id:number,version:string,app_path:string,app_contents_path:string}
local function load_editor_instance_json(project_dir)
  local json_path = vim.fs.joinpath(project_dir, "Library/EditorInstance.json")
  local f = vim.loop.fs_open(json_path, "r", 438)
  if not f then
    error(string.format("%s open failed.", json_path))
  end

  local stat = vim.loop.fs_fstat(f)
  if not stat then
    error(string.format("%s stat failed.", json_path))
  end

  local data = vim.loop.fs_read(f, stat.size, 0)
  if type(data) ~= "string" then
    error(string.format("%s read failed.", json_path))
  end

  local json = vim.fn.json_decode(data)
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

--- @class UnityEditorClient
--- @field client IPC.Client
--- @field project_dir string
--- @field check_timer uv_timer_t?
--- @field retry_count number
--- @field handlers table<string,fun(data:any)>
local Editor = {}

--- create Unity Editor client
---@param project_dir string Unity project directory path
---@return UnityEditorClient
function Editor:new(project_dir)
  local obj = {}
  obj.client = ipc.Client:new()
  obj.handlers = {}
  obj.project_dir = project_dir
  --- @type uv_timer_t?
  obj.check_timer = nil
  obj.retry_count = 0

  setmetatable(obj, self)
  self.__index = self
  return obj
end

--- connect to running Unity Editor
function Editor:connect()
  self:close()

  -- load EditorInstance.json
  local ok, data = pcall(load_editor_instance_json, self.project_dir)
  if not ok then
    vim.notify(
      string.format("Failed to load EditorInstance.json. Please make sure Unity is running.\n%s", data),
      vim.log.levels.ERROR
    )
    return
  end

  -- connect to Unity Editor
  local pipename = string.format("%s-%d", PIPENAME_BASE, data.process_id)
  vim.print("connecting to Unity Editor: " .. pipename)
  self:_ensure_connection(pipename)
end

--- ensure connection to Unity Editor
--- @param pipename string
function Editor:_ensure_connection(pipename)
  -- clear previous timer
  if self.check_timer then
    clear_interval(self.check_timer)
    self.check_timer = nil
  end

  self.check_timer = set_interval(
    1000,
    vim.schedule_wrap(function()
      -- check if connected
      if self.client:is_connected() then
        return
      end

      -- reconnect
      self.client:connect(pipename, function(err)
        if err then
          self.retry_count = self.retry_count + 1
          if self.retry_count > 20 then
            vim.notify(
              string.format("Connection failed. Please make sure Unity is running.: %s", err),
              vim.log.levels.ERROR
            )
            self:close()
          end
          return
        end

        print("connected")
        self.client:read_start(self._handle_message)
      end)
    end)
  )
end

--- close Unity Editor connection
function Editor:close()
  if self.check_timer then
    clear_interval(self.check_timer)
    self.check_timer = nil
  end
  pcall(self.client.close, self.client)
  self.retry_count = 0
end

--- register event callback
---@param event string
---@param callback fun(data:any)
function Editor:on(event, callback)
  -- register event callback
  self.handlers[event] = callback
end

--- check if connected to Unity Editor
---@return boolean
function Editor:is_connected()
  return self.client:is_connected()
end

--- execute static method in Unity Editor
---@param type string Unity object type(needs full qualified name)
---@param method string method name
---@param arguments string[] method arguments
function Editor:execute_method(type, method, arguments)
  self:_send("executeMethod", { type, method, unpack(arguments) })
end

--- send json data to Unity Editor
---@param type string
---@param arguments string[]
function Editor:_send(type, arguments)
  local payload = vim.json.encode({ type = type, arguments = arguments })
  self.client:send(payload .. "\n")
end

--- handle message from Unity Editor
---@param data string
function Editor:_handle_message(data)
  print(data)
  if true then
    return
  end

  -- decode data as json
  local decoded = vim.json.decode(data)
  if type(decoded) ~= "table" then
    error("decode failed")
  end
  -- payload must have `event` and `data`
  if type(decoded.event) ~= "string" then
    error("event is not string")
  end
  if not decoded.data then
    error("data is nil")
  end

  -- call event handlers
  if self.handlers[decoded.event] then
    self.handlers[decoded.event](decoded.data)
  end
end

M.Editor = Editor

return M
