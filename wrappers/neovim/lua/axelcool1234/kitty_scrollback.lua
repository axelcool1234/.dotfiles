local M = {}

function M.setup()
  if vim.env.KITTY_SCROLLBACK_NVIM ~= "true" then
    return
  end

  package.loaded["kitty-scrollback.launch"] = nil
  package.preload["kitty-scrollback.launch"] = function()
    return require("axelcool1234.kitty_scrollback.launch")
  end
end

return M
