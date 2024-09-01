local M = {}

local api = require("unity-editor.api")

function M.setup()
  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function()
      if vim.fn.expand("%:e") == "cs" then
        api.refresh()
      end
    end,
    group = vim.api.nvim_create_augroup("unity", {}),
  })
end

return M
