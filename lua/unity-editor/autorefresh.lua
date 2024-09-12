local M = {}

local globalstate = {
  enabled = false,
}

--- Enable auto-refresh feature
--- This will refresh the Unity project when saving a C# file
function M.enable()
  globalstate.enabled = true
  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = vim.schedule_wrap(function()
      -- check auto-refresh is enabled
      if not M.is_enabled() then
        return
      end

      -- check if the current buffer is a C# file
      local bufnr = vim.api.nvim_get_current_buf()
      local path = vim.api.nvim_buf_get_name(bufnr)
      if not path:match("%.cs$") then
        return
      end

      -- refresh the Unity project
      local api = require("unity-editor.api")
      local project_root = api.find_unity_project_root(bufnr)
      if project_root then
        api.refresh(project_root)
      end
    end),
    group = vim.api.nvim_create_augroup("unity-editor-auto-refresh", {}),
  })
end

--- Disable auto-refresh feature
function M.disable()
  globalstate.enabled = false
end

--- Toggle auto-refresh feature
function M.toggle()
  if M.is_enabled() then
    M.disable()
  else
    M.enable()
  end
end

--- Check if auto-refresh feature is enabled
function M.is_enabled()
  return globalstate.enabled
end

return M
