local M = {}

---@class UnityEditor.RequestMessage
---@field id integer
---@field version string
---@field method string
---@field parameters string[]

---@class UnityEditor.ResponseMessage
---@field id integer
---@field version string
---@field status UnityEditor.ResponseMessage.Status
---@field result string

--- @enum UnityEditor.ResponseMessage.Status
M.Status = {
  OK = 0,
  ERROR = -1,
}

--- Serialize a request message.
---@param method string The method to call.
---@param parameters string[] The parameters to pass to the method.
---@param id integer The request id.
---@return string message The serialized request message.
function M.serialize_request(method, parameters, id)
  -- Treat the newline code as the end of the message.
  return vim.json.encode({
    id = id,
    version = require("unity-editor.package_info").version,
    method = method,
    parameters = parameters,
  }) .. "\n"
end

--- Deserialize a response message.
---@param data string The serialized response message.
---@return UnityEditor.ResponseMessage The deserialized response message.
function M.deserialize_response(data)
  local response = vim.json.decode(data)

  vim.validate({
    response = { response, "table" },
    ["response.version"] = { response.version, "string" },
    ["response.status"] = { response.status, "number" },
    ["response.result"] = { response.result, "string" },
    ["response.id"] = { response.id, "number" },
  })

  return response
end

return M
