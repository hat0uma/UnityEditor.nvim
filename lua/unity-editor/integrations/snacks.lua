---@class UnityEditor.picker
local M = {}

local INITIAL_PREVIEW_MODE = "details"

local severity_icons = {
  error = { icon = "󰅚 ", hl = "DiagnosticError" },
  warning = { icon = "󰀪 ", hl = "DiagnosticWarn" },
  info = { icon = "󰋽 ", hl = "DiagnosticInfo" },
}

--- Highlight filepaths
---@param ctx snacks.picker.preview.ctx
---@param lines string[]
local function highlight_filepaths(ctx, lines)
  for i, line in ipairs(lines) do
    local s, e = line:find("[%w_/\\%.%-]+%.cs:%d+")
    if s then
      vim.api.nvim_buf_set_extmark(ctx.preview.win.buf, ctx.preview:ns(), i - 1, s - 1, {
        end_col = e,
        hl_group = "Directory",
      })
    end
  end
end

--- Preview function that switches between details and file
---@param ctx snacks.picker.preview.ctx
---@return boolean | nil
function M.preview(ctx)
  local mode = ctx.picker.preview_mode or INITIAL_PREVIEW_MODE
  if mode == "file" then
    -- Use built-in file preview
    ctx.preview:wo({ wrap = false })
    return require("snacks").picker.preview.file(ctx)
  else
    -- Show details (stack trace)
    ctx.preview:wo({ wrap = true })
    local lines = vim.split(ctx.item.details or "", "\n")
    ctx.preview:set_lines(lines)
    highlight_filepaths(ctx, lines)
    return
  end
end

--- Toggle preview mode action
---@param picker snacks.Picker
function M.toggle_preview_mode(picker)
  local current = picker.preview_mode or INITIAL_PREVIEW_MODE
  picker.preview_mode = current == "details" and "file" or "details"

  -- Update title to show current mode
  local title = picker.preview_mode == "details" and " Details " or " Source "
  if picker.preview.win:valid() then
    vim.api.nvim_win_set_config(picker.preview.win.win, { title = title })
  end

  -- Clear cache and refresh preview
  picker.preview.item = nil
  picker.preview:reset()
  picker.preview:show(picker)
end

--- Format picker item for display
---@param item snacks.picker.Item
---@param picker snacks.Picker
---@return snacks.picker.Highlight[]
function M.format(item, picker)
  local sev = severity_icons[item.severity] or severity_icons.info
  local ret = {}

  -- Severity icon
  table.insert(ret, { sev.icon, sev.hl })
  table.insert(ret, { " " })

  -- Message (first line only)
  table.insert(ret, { item.text or "" })

  -- Highlight
  require("snacks").picker.highlight.highlight(ret, {
    ["^%[%d%d:%d%d:%d%d%]"] = "Comment", -- timestamp
    ["[%w_/\\%.%-]+%.cs"] = "Directory", -- File path
    ["%(%d+,%d+%)"] = "Comment", -- position (line,col)
    ["error"] = "DiagnosticError",
    ["warning"] = "DiagnosticWarn",
    ["CS%d+"] = "Special", -- code like CS0000
  })
  return ret
end

---@type snacks.picker.finder
function M.find(opts, ctx)
  local items = {} ---@type snacks.picker.finder.Item[]
  require("unity-editor").logs(nil, function(response)
    for i, entry in ipairs(response.items or {}) do
      local col = entry.column == -1 and 0 or entry.column - 1
      items[i] = {
        idx = i,
        text = entry.message,
        details = entry.details,
        file = entry.file,
        pos = { entry.line, col },
        severity = entry.severity,
      }
    end
    ctx.async:resume()
  end)

  --- @async
  --- @type snacks.picker.finder.async
  return function(cb)
    ctx.async:suspend()
    for _, item in ipairs(items) do
      cb(item)
    end
  end
end

--- @type snacks.picker.Config
M.source = {
  source = "unity_logs",
  title = "Unity Logs",
  finder = M.find,
  format = M.format,
  preview = M.preview,
  actions = {
    toggle_preview_mode = M.toggle_preview_mode,
  },
  win = {
    preview = {
      title = " Details ",
    },
    input = {
      keys = {
        ["<C-p>"] = { "toggle_preview_mode", mode = { "i", "n" }, desc = "Toggle preview (Details/Source)" },
      },
    },
    list = {
      keys = {
        ["<C-p>"] = { "toggle_preview_mode", mode = { "n" }, desc = "Toggle preview (Details/Source)" },
      },
    },
  },
}

--- Show logs using snacks.picker
---@param opts? snacks.picker.Config|{}
function M.open(opts)
  Snacks.picker("unity_logs", opts)
end

return M
