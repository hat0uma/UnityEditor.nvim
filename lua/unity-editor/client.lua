local M = {}

local is_windows = vim.uv.os_uname().sysname:match("Windows")

local PIPENAME_BASE = is_windows and "\\\\.\\pipe\\UnityEditorIPC" or "/tmp/UnityEditorIPC"

---@class UnityEditor.Message
---@field method string
---@field parameters string[]

---@class UnityEditor.EditorInstance
---@field process_id number
---@field version string
---@field app_path string
---@field app_contents_path string

--- @class UnityEditor.Client
--- @field client uv_pipe_t
--- @field project_dir string
--- @field handlers table<string,fun(data:any)>
local Client = {}

--- Create new Unity Editor client
---@param project_dir string Unity project directory path
---@return UnityEditor.Client
function Client:new(project_dir)
  local obj = {}
  obj.client = vim.uv.new_pipe(false)
  obj.handlers = {}
  obj.project_dir = project_dir

  setmetatable(obj, self)
  self.__index = self
  return obj
end

--- Connect to Unity Editor
--- If already connected, do nothing.
---@param on_connect fun()
function Client:connect(on_connect)
  if self:is_connected() then
    return
  end

  -- load EditorInstance.json
  local editor_instance = self:_load_editor_instance_json()
  local pipename = self:_pipename(editor_instance)

  -- connect to Unity Editor
  vim.print("connecting to Unity Editor: " .. pipename)
  self.client = vim.uv.new_pipe(false)
  self.client:connect(pipename, function(err)
    self:_handle_connection(err, on_connect)
  end)
end

--- Close connection to Unity Editor
function Client:close()
  pcall(self.client.close, self.client)
end

--- Check if connected to Unity Editor
---@return boolean
function Client:is_connected()
  return self.client and vim.uv.is_active(self.client) or false
end

--- Send message to Unity Editor
---@param message UnityEditor.Message
function Client:send(message)
  local function _send()
    local payload = vim.json.encode(message)
    self.client:write(payload .. "\n")
  end

  -- if not connected, run after connecting
  if not self:is_connected() then
    self:connect(_send)
  else
    _send()
  end
end

--- refresh Unity Editor asset database
--- this will compile scripts and refresh asset database
--- It works like focus on Unity Editor or press Ctrl+R
function Client:request_refresh()
  self:send({ method = "refresh", parameters = {} })
end

--- request Unity Editor to play game
function Client:request_playmode_enter()
  self:send({ method = "playmode_enter", parameters = {} })
end

--- request Unity Editor to stop game
function Client:request_playmode_exit()
  self:send({ method = "playmode_exit", parameters = {} })
end

--- request Unity Editor to toggle play game
function Client:request_playmode_toggle()
  self:send({ method = "playmode_toggle", parameters = {} })
end

--- generate Visual Studio solution file
function Client:request_generate_sln()
  self:send({ method = "generate_sln", parameters = {} })
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

--- handle message from Unity Editor
---@param data string
function Client:_handle_message(data)
  -- TODO: handle message from Unity Editor
  print(data)
end

--- handle connection to Unity Editor
---@param err? string
---@param on_connect? fun()
function Client:_handle_connection(err, on_connect)
  if err then
    vim.notify(string.format("Connection failed. Please make sure Unity is running.: %s", err), vim.log.levels.ERROR)
    return
  end

  -- start reading from Unity Editor
  self.client:read_start(function(err, data)
    if err then
      vim.notify(string.format("Read failed: %s", err), vim.log.levels.ERROR)
      return
    end

    if not data then
      self.client:close()
      return
    end

    -- handle message
    self:_handle_message(data)
  end)

  print("connected to Unity Editor")
  if on_connect then
    on_connect()
  end
end

--- Load EditorInstance.json
---@return UnityEditor.EditorInstance
function Client:_load_editor_instance_json()
  local json_path = vim.fs.joinpath(self.project_dir, "Library/EditorInstance.json")

  -- "Failed to load Library/EditorInstance.json. Please make sure Unity is running.\n%s",
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

M.Client = Client

return M
