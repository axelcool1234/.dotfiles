local M = {}

local function gitlinker_mode()
  local mode = vim.fn.mode()
  if mode:match("^[vV\022]") then
    return "v"
  end

  return "n"
end

function M.copy_permalink()
  require("gitlinker").get_buf_range_url(gitlinker_mode())
end

function M.open_permalink()
  require("gitlinker").get_buf_range_url(gitlinker_mode(), {
    action_callback = require("gitlinker.actions").open_in_browser,
  })
end

function M.copy_repo_url()
  require("gitlinker").get_repo_url()
end

function M.open_repo_url()
  require("gitlinker").get_repo_url({
    action_callback = require("gitlinker.actions").open_in_browser,
  })
end

return M
