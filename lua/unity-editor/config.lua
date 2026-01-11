local M = {}

M.LOG_FILE_PATH = vim.fs.joinpath(vim.fn.stdpath("log"), "unity-editor.log")

---@class UnityEditor.Config
local defaults = {
  autorefresh = true,

  --- @class UnityEditor.Config.Log
  log = {
    --- The log levels to print. see `vim.log.levels`.
    print_level = vim.log.levels.INFO,

    --- The log levels to write to the log file. see `vim.log.levels`.
    file_level = vim.log.levels.DEBUG,

    --- The maximum size of the log file in bytes.
    --- If 0, it does not output.
    max_file_size = 1 * 1024 * 1024,

    --- The maximum number of log files to keep.
    max_backups = 3,
  },
}

--- Setup log handlers
---@param opts UnityEditor.Config
local function setup_logs(opts)
  local log = require("unity-editor.log")
  local logger = log.new_logger()
  logger.add_notify_handler(opts.log.print_level, { title = "unity-editor" })
  logger.add_file_handler(opts.log.file_level, {
    file_path = M.LOG_FILE_PATH,
    max_backups = opts.log.max_backups,
    max_file_size = opts.log.max_file_size,
  })
  log.set_default(logger)
end

---@type UnityEditor.Config
local options

--- Setup config
---@param opts? UnityEditor.Config
---@return UnityEditor.Config
function M.setup(opts)
  ---@type UnityEditor.Config
  options = vim.tbl_deep_extend("force", {}, defaults, opts or {})
  setup_logs(options)
  return options
end

--- Get config
---@param opts? UnityEditor.Config
---@return UnityEditor.Config
function M.get(opts)
  if not options then
    M.setup()
  end
  return vim.tbl_deep_extend("force", options, opts or {})
end

return M
