vim.cmd.colorscheme "tokyonight-night"

vim.opt.guicursor = ""

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true 

-- vim.opt.swapfile = false
-- vim.opt.backup = false
-- vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
-- vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
-- vim.opt.signcolumn = "yes"

vim.opt.updatetime = 50

-- vim.opt.colorcolumn = "80"

vim.opt.grepprg = "rg --vimgrep --smart-case --hidden"
vim.opt.grepformat = "%f:%l:%c:%m"

-- Vimtex
-- Disable opening the quickfix window for warnings
-- vim.g.vimtex_quickfix_mode = 0

-- Set Zathura as the viewer
vim.g.vimtex_view_method = 'zathura'

-- Configure forward search
vim.g.vimtex_view_general_options = '--synctex-forward @line:@col:@pdf %p'

-- Firenvim
vim.g.firenvim_config = {
    globalSettings = { alt = "all" },
    localSettings = {
        [".*"] = {
            cmdline  = "neovim",
            content  = "text",
            priority = 0,
            selector = "textarea",
            takeover = "never"
        },
        ["https?://leetcode.com/.*"] = {
            cmdline  = "neovim",
            content  = "text",
            priority = 1,
            selector = "textarea",
            takeover = "never",
            filename = "leetcode.rs",  -- Set a filename pattern for the buffer
        }
    }
}
-- Leetcode text fitting
if vim.g.started_by_firenvim == true then
  vim.o.guifont = "Monospace:h20"  -- Adjust the font size
end

-- Rustaceanvim
-- vim.g.rustaceanvim = {
--   tools = {
--     test_executor = 'background',
--   },
-- }

-- RustFmt
vim.g.rustfmt_autosave = 1
