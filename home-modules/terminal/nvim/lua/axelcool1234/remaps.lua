vim.g.mapleader = " "

-- Paste from system clipboard
vim.api.nvim_set_keymap('n', '<leader>p', '"+p', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<leader>p', '"+p', { noremap = true, silent = true })

-- Yank to system clipboard
vim.api.nvim_set_keymap('n', '<leader>y', '"+y', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<leader>y', '"+y', { noremap = true, silent = true })

-- CTRL+D / CTRL+U keeps cursor in the middle
vim.api.nvim_set_keymap('n', '<C-d>', '<C-d>zz', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-u>', '<C-u>zz', { noremap = true, silent = true })

-- Replace symbol
vim.api.nvim_set_keymap('n', '<leader>r', '<cmd>lua vim.lsp.buf.rename()<CR>', { noremap = true, silent = true })

-- Code Action
vim.api.nvim_set_keymap('n', '<leader>a', '<cmd>lua vim.lsp.buf.code_action()<CR>', { noremap = true, silent = true })

-- Move through diagnostic
vim.api.nvim_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', { noremap = true, silent = true })

-- Goto declaration/definition/implementation/references
vim.api.nvim_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', { noremap = true, silent = true })

-- Diagnostics Picker
vim.api.nvim_set_keymap('n', '<leader> ', '<cmd>lua vim.lsp.buf.hover()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>s', '<cmd>lua vim.lsp.buf.signature_help()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>d', '<cmd>lua vim.diagnostic.open_float()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>q', '<cmd>lua vim.diagnostic.setloclist()<CR>', { noremap = true, silent = true })

-- Key mappings for nvim-cmp (completion-nvim)
vim.api.nvim_set_keymap('i', '<C-p>', [[<cmd>lua require('cmp').select_prev_item()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', '<C-n>', [[<cmd>lua require('cmp').select_next_item()<CR>]], { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('i', '<C-space>', [[<cmd>lua require('cmp').complete()<CR>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', '<C-e>', [[<cmd>lua require('cmp').close()<CR>]], { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('i', '<tab>', [[<cmd>lua require('cmp').confirm({ select = true })<CR>]], { noremap = true, silent = true })

-- Ultisnips keymappings
vim.g.UltiSnipsExpandTrigger = "<tab>"
vim.g.UltiSnipsJumpForwardTrigger = "<c-j>"
vim.g.UltiSnipsJumpBackwardTrigger = "<c-k>"

-- Telescope keymappings
_G.find_files_in_git_root = function()
    local root = vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
    if vim.v.shell_error == 0 then
        require("telescope.builtin").find_files({ cwd = root })
    else
        require("telescope.builtin").find_files()
    end
end

_G.live_grep_in_git_root = function()
    local root = vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
    if vim.v.shell_error == 0 then
        require("telescope.builtin").live_grep({ cwd = root })
    else
        require("telescope.builtin").live_grep()
    end
end

vim.api.nvim_set_keymap('n', '<leader>f', '<cmd>lua find_files_in_git_root()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>/', '<cmd>lua live_grep_in_git_root()<CR>', { noremap = true, silent = true })
