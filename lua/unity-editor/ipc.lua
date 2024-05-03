--- This module provides IPC client using named pipe.
local M = {}

--- @class IPC.Client
--- @field pipe uv_pipe_t
local Client = {}

--- create ipc client
---@return IPC.Client
function Client:new()
  local obj = {}

  setmetatable(obj, self)
  self.__index = self
  return obj
end

--- connect to ipc server
---@param pipename string
---@param on_connect fun(err: string?)
function Client:connect(pipename, on_connect)
  self.pipe = vim.uv.new_pipe(false)
  vim.uv.pipe_connect(self.pipe, pipename, on_connect)
end

--- check if ipc connection is active
---@return boolean
function Client:is_connected()
  return self.pipe and vim.uv.is_active(self.pipe) or false
end

--- close ipc connection
function Client:close()
  if self.pipe then
    vim.uv.close(self.pipe)
  end
end

function Client:send(data)
  if not self.pipe then
    error("pipe is not initialized")
  end

  if not vim.uv.is_active(self.pipe) then
    error("pipe is not active")
  end

  vim.uv.write(self.pipe, data)
end

--- receive data from ipc server
---@param callback fun(data:string)
function Client:read_start(callback)
  if not self.pipe then
    error("pipe is not initialized")
  end

  vim.uv.read_start(self.pipe, function(err, data)
    if err then
      error("read_start failed: " .. err)
    elseif data then
      callback(data)
    else
      -- EOF
    end
  end)
end

M.Client = Client
return M
