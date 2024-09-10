--- @class UnityEditor.api
local M = {}

local function register_compile_on_save()
  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = vim.schedule_wrap(function()
      local bufnr = vim.api.nvim_get_current_buf()
      local path = vim.api.nvim_buf_get_name(bufnr)
      if not path:match("%.cs$") then
        return
      end

      local api = require("unity-editor.api")
      local project_root = api.find_unity_project_root(bufnr)
      if project_root then
        api.refresh(project_root)
      end
    end),
    group = vim.api.nvim_create_augroup("unity-editor-compile", {}),
  })
end

---Setup
---@param opts? UnityEditor.Config
function M.setup(opts)
  local config = require("unity-editor.config")
  opts = config.setup(opts)

  if opts.compile_on_save then
    register_compile_on_save()
  end
end

return setmetatable(M, {
  __index = function(_, k)
    return require("unity-editor.api")[k]
  end,
})
