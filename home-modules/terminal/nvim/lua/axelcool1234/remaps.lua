-- Leader Key
vim.g.mapleader = " "

-- Helpers
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

-- Mappings
local keymap = vim.api.nvim_set_keymap
local default_opts = { noremap = true, silent = true }
local mappings = {
    -- Telescope keymappings
    { "Find Files", '<leader>f', "<cmd>lua find_files_in_git_root()<CR>", 'n' },
    { "Live Grep", '<leader>/', "<cmd>lua live_grep_in_git_root()<CR>", 'n' },

    -- Paste from system clipboard
    { "Clipboard Paste", '<leader>p', '"+p', {'n', 'v'} },

    -- Yank to system clipboard
    { "Clipboard Yank", '<leader>y', '"+y', {'n', 'v'} },

    -- CTRL+D / CTRL+U keeps cursor in the middle
    { "CTRL+D", '<C-d>', '<C-d>zz', 'n' },
    { "CTRL+U", '<C-u>', '<C-u>zz', 'n' },

    -- Alternatives to ^/$/G (Helix-like bindings)
    { "Goto line end", 'gl', '$', { 'n', 'v' } },
    { "Goto line start", 'gh', '^', { 'n', 'v' } },
    { "Goto last line", 'ge', 'G', { 'n', 'v' } },

    -- Replace symbol
    { "Replace symbol", '<leader>r', "<cmd>lua vim.lsp.buf.rename()<CR>", 'n' },

    -- Code Action
    { "Code Action", '<leader>a', "<cmd>lua vim.lsp.buf.code_action()<CR>", 'n' },

    -- Move through diagnostic
    { "Move through diagnostic (prev)", '[d', "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", 'n' },
    { "Move through diagnostic (next)", ']d', "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", 'n' },

    -- Goto declaration/definition/implementation/references
    { "Goto declaration", 'gD', "<cmd>lua vim.lsp.buf.declaration()<CR>", 'n' },
    { "Goto definition", 'gd', "<cmd>lua vim.lsp.buf.definition()<CR>", 'n' },
    { "Goto implementation", 'gi', "<cmd>lua vim.lsp.buf.implementation()<CR>", 'n' },
    { "Goto references", 'gr', "<cmd>lua vim.lsp.buf.references()<CR>", 'n' },

    -- Diagnostics
    { "Hover", '<leader> ', "<cmd>lua vim.lsp.buf.hover()<CR>", 'n' },
    { "Signature Help", '<leader>s', "<cmd>lua vim.lsp.buf.signature_help()<CR>", 'n' },
    { "Open Diagnostic float", '<leader>d', "<cmd>lua vim.diagnostic.open_float()<CR>", 'n' },
    { "Set Diagnostic loclist", '<leader>q', "<cmd>lua vim.diagnostic.setloclist()<CR>", 'n' },

    -- Key mappings for nvim-cmp (completion-nvim)
    { "Completion: Previous item", '<C-p>', "<cmd>lua require('cmp').select_prev_item()<CR>", 'i' },
    { "Completion: Next item", '<C-n>', "<cmd>lua require('cmp').select_next_item()<CR>", 'i' },
    { "Completion: Close", '<C-e>', "<cmd>lua require('cmp').close()<CR>", 'i' },

    -- Key mappings for undotree
    { "Toggle Undotree", '<leader>u', "<cmd>lua vim.cmd.UndotreeToggle()<CR>", 'n' },

    -- Ultisnips keymappings
    { "UltiSnips: Expand Trigger", '<tab>', "<cmd>lua UltiSnips#ExpandSnippet()<CR>", 'n' },
    { "UltiSnips: Jump Forward", '<c-j>', "<cmd>lua UltiSnips#JumpForwards()<CR>", 'n' },
    { "UltiSnips: Jump Backward", '<c-k>', "<cmd>lua UltiSnips#JumpBackwards()<CR>", 'n' },

    -- Flash plugin keymappings
    { "Flash", 's', "<cmd>lua require('flash').jump()<CR>", {'n', 'x', 'o'} },
    { "Flash Treesitter", 'S', "<cmd>lua require('flash').treesitter()<CR>", {'n', 'x', 'o'} },
    { "Remote Flash", 'r', "<cmd>lua require('flash').remote()<CR>", 'o' },
    { "Treesitter Search", 'R', "<cmd>lua require('flash').treesitter_search()<CR>", {'o', 'x'} },
    { "Toggle Flash Search", '<c-s>', "<cmd>lua require('flash').toggle()<CR>", 'c' },

    -- Bufferline keymappings
    { "Prev Buffer", 'H', "<cmd>BufferLineCyclePrev<cr>", 'n' },
    { "Next Buffer", 'L', "<cmd>BufferLineCycleNext<cr>", 'n' },
    { "Close Buffer", 'gq', "<cmd>bdelete<CR>", 'n' },

}

for _, mapping in ipairs(mappings) do
    local desc, lhs, rhs, modes, opts = unpack(mapping)
    opts = opts or {}
    modes = type(modes) == "table" and modes or {modes}

    for _, mode in ipairs(modes) do
        local final_opts = vim.tbl_extend("force", default_opts, opts, { desc = desc })
        keymap(mode, lhs, rhs, final_opts)
    end
end
