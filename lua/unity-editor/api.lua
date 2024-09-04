local M = {}

local Editor = require("unity-editor.editor").Editor

--- @type table<string,UnityEditorClient>
local editors = {}

--- get Unity Editor client instance
---@param project_dir string Unity project directory path
---@return UnityEditorClient
local function get_project_client(project_dir)
  local editor = editors[project_dir]
  if not editor then
    editor = Editor:new(project_dir)
    editors[project_dir] = editor
  end
  return editor
end

--- execute Unity Editor command
---@param type string
---@param arguments string[]
---@return fun(project_dir?: string)
local function unity_message_sender(type, arguments)
  ---@param project_dir? string
  return function(project_dir)
    if not project_dir then
      project_dir = assert(vim.uv.cwd())
    end

    -- execute unity-side method.
    local editor = get_project_client(project_dir)
    editor:send(type, arguments)
  end
end

--- refresh Unity Editor asset database
--- this will compile scripts and refresh asset database
--- It works like focus on Unity Editor or press Ctrl+R
M.refresh = unity_message_sender("refresh", {})

--- request Unity Editor to play game
M.playmode_enter = unity_message_sender("playmode_enter", {})

--- request Unity Editor to stop game
M.playmode_exit = unity_message_sender("playmode_exit", {})

--- request Unity Editor to toggle play game
M.playmode_toggle = unity_message_sender("playmode_toggle", {})

--- generate Visual Studio solution file
M.generate_sln = unity_message_sender("generate_sln", {})

--- load Unity EditorInstance.json
---@param path string path to EditorInstance.json
---@return UnityEditorInstance
local function load_editor_instance_json(path)
  local json_path = vim.fs.joinpath(path)
  local f = assert(vim.uv.fs_open(json_path, "r", 438))
  local stat = assert(vim.uv.fs_fstat(f))
  local data = assert(vim.uv.fs_read(f, stat.size, 0))
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

---@class UnityEditorInstance
---@field process_id number
---@field version string
---@field app_path string
---@field app_contents_path string

--- Find Unity Editor Instance
---@param bufnr integer
---@return UnityEditorInstance?
function M.find_editor_instance(bufnr)
  local buf = vim.api.nvim_buf_get_name(bufnr)
  local found = vim.fs.find("Library/EditorInstance.json", {
    upward = true,
    type = "file",
    stop = vim.uv.os_homedir(),
    path = vim.fs.dirname(buf),
  })

  if vim.tbl_isempty(found) then
    return nil
  end

  return load_editor_instance_json(found[1])
end

return M
