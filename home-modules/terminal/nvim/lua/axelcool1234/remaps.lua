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

-- Which-Key labels
require("which-key").register({
    -- Telescope keymappings
    ["<leader>f"] = { "<cmd>lua find_files_in_git_root()<CR>", "Find Files", mode = "n", noremap = true, silent = true },
    ["<leader>/"] = { "<cmd>lua live_grep_in_git_root()<CR>", "Live Grep", mode = "n", noremap = true, silent = true },

    -- Paste from system clipboard
    ["<leader>p"] = { '"+p', "Paste from system clipboard", noremap = true, silent = true },
    ["v<leader>p"] = { '"+p', "Paste from system clipboard", noremap = true, silent = true },

    -- Yank to system clipboard
    ["<leader>y"] = { '"+y', "Yank to system clipboard", noremap = true, silent = true },
    ["v<leader>y"] = { '"+y', "Yank to system clipboard", noremap = true, silent = true },
    
    -- CTRL+D / CTRL+U keeps cursor in the middle
    ["<C-d>"] = { "<C-d>zz", "CTRL+D keeps cursor in the middle", mode = "n", noremap = true, silent = true },
    ["<C-u>"] = { "<C-u>zz", "CTRL+U keeps cursor in the middle", mode = "n", noremap = true, silent = true },

    -- Replace symbol
    ["<leader>r"] = { "<cmd>lua vim.lsp.buf.rename()<CR>", "Replace symbol", mode = "n", noremap = true, silent = true },

    -- Code Action
    ["<leader>a"] = { "<cmd>lua vim.lsp.buf.code_action()<CR>", "Code Action", mode = "n", noremap = true, silent = true },

    -- Move through diagnostic
    ["[d"] = { "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", "Move through diagnostic (prev)", noremap = true, silent = true, mode = "n" },
    ["]d"] = { "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", "Move through diagnostic (next)", noremap = true, silent = true },

    -- Goto declaration/definition/implementation/references
    ["gD"] = { "<cmd>lua vim.lsp.buf.declaration()<CR>", "Goto declaration", noremap = true, silent = true },
    ["gd"] = { "<cmd>lua vim.lsp.buf.definition()<CR>", "Goto definition", noremap = true, silent = true },
    ["gi"] = { "<cmd>lua vim.lsp.buf.implementation()<CR>", "Goto implementation", noremap = true, silent = true },
    ["gr"] = { "<cmd>lua vim.lsp.buf.references()<CR>", "Goto references", noremap = true, silent = true },

    -- Diagnostics 
    ["<leader> "] = { "<cmd>lua vim.lsp.buf.hover()<CR>", "Hover", noremap = true, silent = true },
    ["<leader>s"] = { "<cmd>lua vim.lsp.buf.signature_help()<CR>", "Signature Help", noremap = true, silent = true },
    ["<leader>d"] = { "<cmd>lua vim.diagnostic.open_float()<CR>", "Open Diagnostic float", noremap = true, silent = true },
    ["<leader>q"] = { "<cmd>lua vim.diagnostic.setloclist()<CR>", "Set Diagnostic loclist", noremap = true, silent = true },

    -- Key mappings for nvim-cmp (completion-nvim)
    ["<C-p>"] = { "<cmd>lua require('cmp').select_prev_item()<CR>", "Completion: Previous item", mode = "i", noremap = true, silent = true },
    ["<C-n>"] = { "<cmd>lua require('cmp').select_next_item()<CR>", "Completion: Next item", mode = "i", noremap = true, silent = true },
    ["<C-e>"] = { "<cmd>lua require('cmp').close()<CR>", "Completion: Close", mode = "i", noremap = true, silent = true },

    -- Key mappings for undotree
    ["<leader>u"] = { "<cmd>lua vim.cmd.UndotreeToggle()<CR>", "Toggle Undotree", mode = "n", noremap = true, silent = true },

    -- Ultisnips keymappings
    ["<tab>"] = { "<cmd>lua UltiSnips#ExpandSnippet()<CR>", "UltiSnips: Expand Trigger", noremap = true, silent = true },
    ["<c-j>"] = { "<cmd>lua UltiSnips#JumpForwards()<CR>", "UltiSnips: Jump Forward", noremap = true, silent = true },
    ["<c-k>"] = { "<cmd>lua UltiSnips#JumpBackwards()<CR>", "UltiSnips: Jump Backward", noremap = true, silent = true },
})
 
