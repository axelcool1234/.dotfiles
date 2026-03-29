vim.opt.termguicolors = true

local bufferline_config = {}

local function setup_bufferline()
  require("bufferline").setup(bufferline_config)
end

setup_bufferline()

vim.api.nvim_create_autocmd("User", {
  pattern = "NoctaliaThemeReloaded",
  callback = function()
    setup_bufferline()
    vim.cmd("redrawtabline")
  end,
})
