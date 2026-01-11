--
-- Message Format
--
-- +------------------+------------------+-------------------+
-- | Magic (4 bytes)  | Length (4 bytes) | Payload (JSON)    |
-- +------------------+------------------+-------------------+
--
-- - Magic: 0x55 0x4E 0x56 0x4D ("UNVM")
-- - Length: little-endian uint32
-- - Max Message length: 1MB
--

local M = {}

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

-- Protocol constants
local MAGIC = string.char(0x55, 0x4E, 0x56, 0x4D) -- "UNVM"
M.HEADER_SIZE = 8
M.MAX_MESSAGE_SIZE = 1024 * 1024 -- 1MB

--- Pack a 32-bit unsigned integer as little-endian bytes
---@param n integer
---@return string bytes 4 bytes in little-endian order
local function pack_uint32_le(n)
  return string.char(band(n, 0xFF), band(rshift(n, 8), 0xFF), band(rshift(n, 16), 0xFF), band(rshift(n, 24), 0xFF))
end

--- Unpack a 32-bit unsigned integer from little-endian bytes
---@param s string 4 bytes in little-endian order
---@param offset? integer starting position (1-based, default 1)
---@return integer n
local function unpack_uint32_le(s, offset)
  offset = offset or 1
  local b0, b1, b2, b3 = s:byte(offset, offset + 3)
  return bor(b0, lshift(b1, 8), lshift(b2, 16), lshift(b3, 24))
end

---@class UnityEditor.RequestMessage
---@field id integer
---@field version string
---@field method string
---@field parameters string JSON string for method-specific parameters

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

--- Serialize a request message with binary header.
---@param method string The method to call.
---@param parameters table|nil The parameters to pass to the method (will be JSON-encoded).
---@param id integer The request id.
---@return string message The serialized request message with header.
function M.serialize_request(method, parameters, id)
  local json_data = vim.json.encode({
    id = id,
    version = require("unity-editor.package_info").version,
    method = method,
    parameters = vim.json.encode(parameters or {}),
  })
  local header = MAGIC .. pack_uint32_le(#json_data)
  return header .. json_data
end

--- Deserialize the message header.
---@param data string The header data (8 bytes).
---@return integer? length The payload length, or nil on error.
---@return string? err The error message if failed.
function M.deserialize_header(data)
  if #data < M.HEADER_SIZE then
    return nil, "Header too short"
  end
  local magic = data:sub(1, 4)
  if magic ~= MAGIC then
    return nil, "Invalid magic number"
  end
  local length = unpack_uint32_le(data, 5)
  if length > M.MAX_MESSAGE_SIZE then
    return nil, "Message too large"
  end
  return length
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
