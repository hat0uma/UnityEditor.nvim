---@diagnostic disable: await-in-sync
local Client = require("unity-editor.ipc.client").Client
local package_info = require("unity-editor.package_info")
local is_windows = vim.uv.os_uname().sysname:match("Windows")

--- Create a dummy server for testing
---@param pipename string
---@param on_receive? fun(client: uv_pipe_t, data: string)
---@return uv_pipe_t
local function start_dummy_server(pipename, on_receive)
  local server = vim.uv.new_pipe(false)
  assert(server:bind(pipename))
  server:listen(128, function(err)
    assert(not err, err)
    local client = vim.uv.new_pipe(false)
    server:accept(client)
    client:read_start(function(err, data)
      assert(data, err)
      if data then
        if on_receive then
          on_receive(client, data)
        end
      else
        client:close()
      end
    end)
  end)
  return server
end

describe("UnityEditor.Client with Dummy Server", function()
  local project_dir = "./tests/fixtures"
  local pipename = is_windows and "\\\\.\\pipe\\UnityEditorIPC-1234" or "/tmp/UnityEditorIPC-1234"
  local thread = coroutine.running()

  -- Start the dummy server before running tests
  local server ---@type uv_pipe_t?
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
    local ok, err = client:connect_async()
    assert.is_true(ok)
    assert.is_nil(err)
  end)

  it("should close the connection", function() ---@async
    server = start_dummy_server(pipename)
    local client = Client:new(project_dir)
    client:connect_async()
    client:close()
    assert.is_false(client:is_connected())
  end)

  it("should check connection status", function() ---@async
    server = start_dummy_server(pipename)
    local client = Client:new(project_dir)
    assert.is_false(client:is_connected())
    client:connect_async()
    assert.is_true(client:is_connected())
  end)

  it("should send request and handle response", function()
    local request_data = { method = "test_method", parameters = {}, version = package_info.version }
    local response_data = { result = "ok", status = 0, version = package_info.version }

    -- Start the dummy server
    server = start_dummy_server(pipename, function(client, data)
      local request = vim.json.decode(data)
      assert.are.same(request, request_data)
      client:write(vim.json.encode(response_data) .. "\n")
    end)

    -- Create a client and send a request
    local client = Client:new(project_dir)
    client:_request(request_data.method, request_data.parameters, function(data, err)
      assert.is_nil(err)
      assert.are.same(data, response_data)
      coroutine.resume(thread)
    end)

    coroutine.yield()
  end)
end)
