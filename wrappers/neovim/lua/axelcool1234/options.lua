vim.opt.guicursor = ""

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true 

-- vim.opt.swapfile = false
-- vim.opt.backup = false
-- vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
-- vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true
vim.opt.list = true
vim.opt.virtualedit = "onemore"
vim.opt.listchars = {
  tab = "» ",
  trail = "·",
  nbsp = "␣",
  eol = "↴",
}

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

local lsp_attach_group = vim.api.nvim_create_augroup('axelcool1234-lsp-attach', { clear = true })

local function toggle_inlay_hints(bufnr)
  local filter = { bufnr = bufnr }
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
end

vim.api.nvim_create_autocmd('LspAttach', {
  group = lsp_attach_group,
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufnr = args.buf

    if not client then
      return
    end

    vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

    if client:supports_method('textDocument/inlayHint') then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      vim.keymap.set('n', '<leader>i', function()
        toggle_inlay_hints(bufnr)
      end, { buffer = bufnr, desc = 'Toggle inlay hints', silent = true })
    end
  end,
})

-- CPP
vim.api.nvim_create_autocmd("FileType", {
    pattern = "cpp",
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.expandtab = true
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.softtabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.expandtab = true
    end,
})
