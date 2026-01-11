---@diagnostic disable: await-in-sync
local Client = require("unity-editor.client").Client
local package_info = require("unity-editor.package_info")
local is_windows = vim.uv.os_uname().sysname:match("Windows")

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

-- Protocol constants for dummy server
local MAGIC = string.char(0x55, 0x4E, 0x56, 0x4D) -- "UNVM"
local HEADER_SIZE = 8

--- Pack a 32-bit unsigned integer as little-endian bytes
---@param n integer
---@return string
local function pack_uint32_le(n)
  return string.char(band(n, 0xFF), band(rshift(n, 8), 0xFF), band(rshift(n, 16), 0xFF), band(rshift(n, 24), 0xFF))
end

--- Unpack a 32-bit unsigned integer from little-endian bytes
---@param s string
---@param offset? integer
---@return integer
local function unpack_uint32_le(s, offset)
  offset = offset or 1
  local b0, b1, b2, b3 = s:byte(offset, offset + 3)
  return bor(b0, lshift(b1, 8), lshift(b2, 16), lshift(b3, 24))
end

--- Serialize a response message with binary header (for dummy server)
---@param response table
---@return string
local function serialize_response(response)
  local json_data = vim.json.encode(response)
  local header = MAGIC .. pack_uint32_le(#json_data)
  return header .. json_data
end

--- Create a dummy server for testing
---@param pipename string
---@param on_receive? fun(client: uv.uv_pipe_t, json_payload: string)
---@return uv.uv_pipe_t
local function start_dummy_server(pipename, on_receive)
  local server = assert(vim.uv.new_pipe(false))
  assert(server:bind(pipename))
  server:listen(128, function(listen_err)
    assert(not listen_err, listen_err)
    local client = assert(vim.uv.new_pipe(false))
    server:accept(client)

    local buffer = "" --- @type string
    client:read_start(function(read_err, data)
      if not data then
        client:read_stop()
        client:close()
        return
      end

      buffer = buffer .. data
      -- Try to parse complete messages from buffer
      while #buffer >= HEADER_SIZE do
        local magic = buffer:sub(1, 4)
        if magic ~= MAGIC then
          error("Invalid magic number in test server")
        end
        local length = unpack_uint32_le(buffer, 5)
        if #buffer < HEADER_SIZE + length then
          -- Wait for more data
          break
        end
        -- Extract payload
        local payload = buffer:sub(HEADER_SIZE + 1, HEADER_SIZE + length)
        buffer = buffer:sub(HEADER_SIZE + length + 1)
        if on_receive then
          on_receive(client, payload)
        end
      end
    end)
  end)
  return server
end

local project_dir = "./tests/fixtures"
local pipename = is_windows and "\\\\.\\pipe\\UnityEditorIPC-1234" or "/tmp/UnityEditorIPC-1234"

describe("UnityEditor.Client with Dummy Server", function()
  local thread = coroutine.running()

  -- Start the dummy server before running tests
  local server ---@type uv.uv_pipe_t?
  after_each(function()
    if server then
      server:close()
      server = nil
    end
  end)

  it("should initialize correctly", function()
    local client = Client:new(project_dir)
    assert.is.not_nil(client)
    assert.are.equal(client._project_dir, project_dir)
  end)

  it("should connect to Dummy Server", function() ---@async
    server = start_dummy_server(pipename)
    local client = Client:new(project_dir)
    local ok, err = client:_connect_async()
    assert.is_true(ok)
    assert.is_nil(err)
  end)

  it("should close the connection", function() ---@async
    server = start_dummy_server(pipename)
    local client = Client:new(project_dir)
    client:_connect_async()
    client:_close()
    assert.is_false(client:is_connected())
  end)

  it("should check connection status", function() ---@async
    server = start_dummy_server(pipename)
    local client = Client:new(project_dir)
    assert.is_false(client:is_connected())
    client:_connect_async()
    assert.is_true(client:is_connected())
  end)

  it("should send request and handle response", function()
    local response_data = { id = 0, result = "ok", status = 0, version = package_info.version } -- id will be set dynamically

    -- Start the dummy server
    server = start_dummy_server(pipename, function(pipe, payload)
      local request = vim.json.decode(payload)
      -- Echo back response with same id as request
      response_data.id = request.id
      pipe:write(serialize_response(response_data))
    end)

    -- Create a client and send a request
    local client = Client:new(project_dir)
    client:request("test_method", nil, function(data, err)
      vim.schedule(function()
        assert.is_nil(err)
        assert.are.same(data.result, response_data.result)
        assert.are.same(data.status, response_data.status)
        coroutine.resume(thread)
      end)
    end)

    coroutine.yield()
  end)
end)
