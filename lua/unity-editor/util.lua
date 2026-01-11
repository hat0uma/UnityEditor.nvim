local M = {}
local log = require("unity-editor.log")

---@async
--- Wait for ms milliseconds
---@param ms integer milliseconds
function M.wait_for_milliseconds(ms)
  local thread = coroutine.running()
  vim.defer_fn(
    vim.schedule_wrap(function()
      coroutine.resume(thread)
    end),
    ms
  )
  coroutine.yield()
end

---@async
---@param label string
---@param max_retries integer
---@param interval integer
---@param fn async fun(): string?
---@return boolean ok
function M.run_with_retry(label, max_retries, interval, fn)
  for i = 1, max_retries do
    local err = fn()
    if not err then
      return true
    end

    log.debug("(%d/%d) %s Retrying... %s", i, max_retries, label, err or "")
    M.wait_for_milliseconds(interval)
  end

  return false
end

---@class UnityEditor.EditorInstance
---@field process_id number
---@field version string
---@field app_path string
---@field app_contents_path string

--- Load EditorInstance.json
---@param project_dir string
---@return UnityEditor.EditorInstance
function M.load_editor_instance_json(project_dir)
  local json_path = vim.fs.joinpath(project_dir, "Library/EditorInstance.json")

  -- open EditorInstance.json
  local err, f
  f, err = vim.uv.fs_open(json_path, "r", 438)
  if not f then
    error(string.format("%s open failed. %s", json_path, err))
  end

  -- get file size
  local stat
  stat, err = vim.uv.fs_fstat(f)
  if not stat then
    vim.uv.fs_close(f)
    error(string.format("%s stat failed. %s", json_path, err))
  end

  -- read file
  local data
  data, err = vim.uv.fs_read(f, stat.size, 0)
  vim.uv.fs_close(f)
  if type(data) ~= "string" then
    error(string.format("%s read failed. %s", json_path, err))
  end

  -- decode json
  local json = vim.json.decode(data)
  if type(json) ~= "table" then
    error(string.format("%s decode failed. %s", json_path, err))
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

return M
