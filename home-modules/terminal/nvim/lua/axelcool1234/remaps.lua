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

_G.open_lazygit_in_wezterm = function()
  local current_cwd = vim.fn.getcwd()
  local wezterm_command = string.format("wezterm cli split-pane --right --cwd '%s' lazygit", current_cwd)
  vim.fn.system(wezterm_command)
end

_G.open_terminal_in_wezterm = function()
  local current_cwd = vim.fn.getcwd()
  local wezterm_command = string.format("wezterm cli split-pane --right --cwd '%s'", current_cwd)
  vim.fn.system(wezterm_command)
end

_G.wezterm_pane_move = function(direction)
  vim.fn.system('wezterm cli activate-pane-direction ' .. direction)
end

-- Texlab variables
-- _G.is_compiling = false
-- _G.compilation_buffer = nil
-- _G.compilation_timer = nil
--
-- -- Function to start compilation
-- _G.texlab_build_and_search = function() 
--     -- Set flag to indicate compilation is active
--     _G.is_compiling = true
--
--     -- Trigger build in the designated compilation buffer
--     if _G.compilation_buffer then
--         vim.api.nvim_buf_call(_G.compilation_buffer, function()
--             vim.cmd('TexlabBuild')
--         end)
--     else
--         _G.is_compiling = false
--         -- Stop any running timer
--         if _G.compilation_timer then
--             _G.compilation_timer:stop()
--             _G.compilation_timer:close()
--             _G.compilation_timer = nil
--         end
--         print("Compilation buffer not set")
--         return
--     end
--
--     -- Wait for build to complete (adjust delay as needed)
--     _G.compilation_timer = vim.loop.new_timer()
--     _G.compilation_timer:start(1000, 0, vim.schedule_wrap(function()
--         -- Check if still compiling (flag could be cleared if compilation is stopped)
--         if _G.is_compiling then
--             vim.api.nvim_buf_call(_G.compilation_buffer, function()
--                 vim.cmd('TexlabForward')
--             end)
--         end
--     end))
-- end
--
-- _G.start_compilation = function()
--     if not _G.is_compiling then
--         _G.compilation_buffer = vim.api.nvim_get_current_buf()
--         vim.cmd('autocmd BufWritePost * lua if _G.is_compiling then _G.texlab_build_and_search() end')
--         _G.is_compiling = true
--     end
-- end
--
-- _G.stop_compilation = function()
--     if _G.is_compiling then
--         vim.cmd('autocmd! BufWritePost *')
--         _G.is_compiling = false
--         _G.compilation_buffer = nil
--         -- Stop any running timer
--         if _G.compilation_timer then
--             _G.compilation_timer:stop()
--             _G.compilation_timer:close()
--             _G.compilation_timer = nil
--         end
--         print("Compilation stopped")
--     else
--         print("No active compilation to stop")
--     end
-- end

-- Mappings
function set_mappings(mappings, default_opts)
  local keymap = vim.api.nvim_set_keymap
  for _, mapping in ipairs(mappings) do
      local desc, lhs, rhs, modes, opts = unpack(mapping)
      opts = opts or {}
      modes = type(modes) == "table" and modes or {modes}

      for _, mode in ipairs(modes) do
          local final_opts = vim.tbl_extend("force", default_opts, opts, { desc = desc })
          keymap(mode, lhs, rhs, final_opts)
      end
  end
end

local default_opts = { noremap = true, silent = true }
local mappings = {
    -- Telescope keymappings
    { "Find Files", '<leader>f', "<cmd>lua find_files_in_git_root()<CR>", 'n' },
    { "Live Grep", '<leader>/', "<cmd>lua live_grep_in_git_root()<CR>", 'n' },

    -- LaTeX Build Command (texlab LSP) (replaced with vimtex)
    -- { "Build LaTeX", '<leader>\\ll', "<cmd>lua start_compilation()<CR><cmd>lua texlab_build_and_search()<CR>", 'n' }, 
    -- { "End LaTeX Building", '<leader>\\lk', "<cmd>lua stop_compilation()<CR>", 'n' }, 

    -- Paste from system clipboard
    { "Clipboard Paste", '<leader>p', '"+p', {'n', 'v'} },

    -- Yank to system clipboard
    { "Clipboard Yank", '<leader>y', '"+y', {'n', 'v'} },

    -- Replace
    { "Replace", 'gR', '<cmd>normal! "_d0P"<CR>', {'n', 'v'} },
    { "Clipboard Replace ", '<leader>gR', '<cmd>normal! "_d"+P<CR>', {'n', 'v'} },

    -- CTRL+D / CTRL+U keeps cursor in the middle
    { "CTRL+D", '<C-d>', '<C-d>zz', 'n' },
    { "CTRL+U", '<C-u>', '<C-u>zz', 'n' },

    -- Alternatives to ^/$/G/CTRL+R (Helix-like bindings)
    { "Goto line end", 'gl', '$', { 'n', 'v' } },
    { "Goto line start", 'gh', '^', { 'n', 'v' } },
    { "Goto last line", 'ge', 'G', { 'n', 'v' } },
    { "Redo", 'U', '<C-R>', { 'n' , 'v' } },

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
    { "Open Diagnostic float", '<leader>dd', "<cmd>lua vim.diagnostic.open_float()<CR>", 'n' },
    { "Set Diagnostic loclist", '<leader>q', "<cmd>lua vim.diagnostic.setloclist()<CR>", 'n' },

    -- Key mappings for nvim-cmp (completion-nvim)
    { "Completion: Previous item", '<C-p>', "<cmd>lua require('cmp').select_prev_item()<CR>", 'i' },
    { "Completion: Next item", '<C-n>', "<cmd>lua require('cmp').select_next_item()<CR>", 'i' },
    { "Completion: Close", '<C-e>', "<cmd>lua require('cmp').close()<CR>", 'i' },
    { "Completion: Accept", '<C-Space>', "<cmd>lua require('cmp').confirm({ select = true })<CR>", 'i' },

    -- Key mappings for nvim-dap (debug adapter)
    { "+Debug", "<leader>d", "", { "n", "v" } },
    { "Breakpoint Condition", "<leader>dB", "<cmd>lua require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", 'n' },
    { "Toggle Breakpoint", "<leader>db", "<cmd>lua require('dap').toggle_breakpoint()<CR>", 'n' },
    { "Continue", "<leader>dc", "<cmd>lua require('dap').continue()<CR>", 'n' },
    { "Run with Args", "<leader>da", "<cmd>lua require('dap').continue({ before = get_args })<CR>", 'n' },
    { "Run to Cursor", "<leader>dC", "<cmd>lua require('dap').run_to_cursor()<CR>", 'n' },
    { "Go to Line (No Execute)", "<leader>dg", "<cmd>lua require('dap').goto_()<CR>", 'n' },
    { "Step Into", "<leader>di", "<cmd>lua require('dap').step_into()<CR>", 'n' },
    { "Down", "<leader>dj", "<cmd>lua require('dap').down()<CR>", 'n' },
    { "Up", "<leader>dk", "<cmd>lua require('dap').up()<CR>", 'n' },
    { "Run Last", "<leader>dl", "<cmd>lua require('dap').run_last()<CR>", 'n' },
    { "Step Out", "<leader>do", "<cmd>lua require('dap').step_out()<CR>", 'n' },
    { "Step Over", "<leader>dO", "<cmd>lua require('dap').step_over()<CR>", 'n' },
    { "Pause", "<leader>dp", "<cmd>lua require('dap').pause()<CR>", 'n' },
    { "Toggle REPL", "<leader>dr", "<cmd>lua require('dap').repl.toggle()<CR>", 'n' },
    { "Session", "<leader>ds", "<cmd>lua require('dap').session()<CR>", 'n' },
    { "Terminate", "<leader>dt", "<cmd>lua require('dap').terminate()<CR>", 'n' },
    { "Widgets", "<leader>dw", "<cmd>lua require('dap.ui.widgets').hover()<CR>", 'n' },
    { "Eval", "<leader>de", "<cmd>lua require('dapui').eval()<CR>", { 'n', 'v' } },
    { "Dap UI", "<leader>du", "<cmd>lua require('dapui').toggle()<CR>", 'n' },

    -- Testing (with Neotest)
    { "+Test", "<leader>t", "", 'n' },
    { "Run File", "<leader>tt", "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<CR>", 'n' },
    { "Run All Test Files", "<leader>tT", "<cmd>lua require('neotest').run.run(vim.uv.cwd())<CR>", 'n' },
    { "Run Nearest", "<leader>tr", "<cmd>lua require('neotest').run.run()<CR>", 'n' },
    { "Run Last", "<leader>tl", "<cmd>lua require('neotest').run.run_last()<CR>", 'n' },
    { "Toggle Summary", "<leader>ts", "<cmd>lua require('neotest').summary.toggle()<CR>", 'n' },
    { "Show Output", "<leader>to", "<cmd>lua require('neotest').output.open({ enter = true, auto_close = true })<CR>", 'n' },
    { "Toggle Output Panel", "<leader>tO", "<cmd>lua require('neotest').output_panel.toggle()<CR>", 'n' },
    { "Stop", "<leader>tS", "<cmd>lua require('neotest').run.stop()<CR>", 'n' },
    { "Toggle Watch", "<leader>tw", "<cmd>lua require('neotest').watch.toggle(vim.fn.expand('%'))<CR>", 'n' },
    -- { "Debug Nearest", '<leader>td', "<cmd>lua require('neotest').run.run({ strategy = 'dap' })<CR>", 'n' },

    -- Key mappings for undotree
    { "Toggle Undotree", '<leader>u', "<cmd>lua vim.cmd.UndotreeToggle()<CR>", 'n' },

    -- UltiSnips keymappings
    -- Note: Due to my Wezterm keybindings making <C-;> be the up arrow and <C-;> be the down arrow, I have 
    -- rebound the UltiSnips keymappings accordingly
    { "UltiSnips: Expand Trigger", '<tab>', "<cmd>call UltiSnips#ExpandSnippet()<CR>", { "i", "s" } },
    -- { "UltiSnips: Jump Forward", '<C-;>', "<cmd>call UltiSnips#JumpForwards()<CR>", { "i", "s" } },
    { "UltiSnips: Jump Forward", '<Up>', "<cmd>call UltiSnips#JumpForwards()<CR>", { "i", "s" } },
    -- { "UltiSnips: Jump Backward", '<C-:>', "<cmd>call UltiSnips#JumpBackwards()<CR>", { "i", "s" } },
    { "UltiSnips: Jump Backward", '<Down>', "<cmd>call UltiSnips#JumpBackwards()<CR>", { "i", "s" } },

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

    -- Terminal-based keymappings
    { "Lazygit", "<leader>gg", "<cmd>lua open_lazygit_in_wezterm()<CR>", 'n' },
    { "Terminal", "<leader>gt", "<cmd>lua open_terminal_in_wezterm()<CR>", 'n' },
    { "Left Pane", '<C-h>', '<cmd>lua wezterm_pane_move("Left")<CR>', 'n' },
    { "Right Pane", '<C-l>', '<cmd>lua wezterm_pane_move("Right")<CR>', 'n' },
    { "Above Pane", '<C-k>', '<cmd>lua wezterm_pane_move("Right")<CR>', 'n' },
    { "Below Pane", '<C-j>', '<cmd>lua wezterm_pane_move("Down")<CR>', 'n' },

    -- Oil keymappings
    { "Open Parent Directory", "-", "<cmd>Oil<CR>", 'n' },
    { "Open Parent Directory (Float)", "<leader>-", "<cmd>lua require('oil').toggle_float()<CR>", 'n' },

    -- Harpoon keymappings
    { "+Harpoon", "<leader>h", "", 'n' },
    { "Harpoon File 1", '<leader>h1', "<cmd>lua require('harpoon'):list():select(1) <CR>", 'n' },
    { "Harpoon File 2", '<leader>h2', "<cmd>lua require('harpoon'):list():select(2) <CR>", 'n' },
    { "Harpoon File 3", '<leader>h3', "<cmd>lua require('harpoon'):list():select(3) <CR>", 'n' },
    { "Harpoon File 4", '<leader>h4', "<cmd>lua require('harpoon'):list():select(4) <CR>", 'n' },
    { "Harpoon File 5", '<leader>h5', "<cmd>lua require('harpoon'):list():select(5) <CR>", 'n' },
    { "Harpoon Add File", '<leader>ha', "<cmd>lua require('harpoon'):list():add() <CR>", 'n' },
    { "Harpoon Quick Menu", '<leader>hh', "<cmd>lua require('harpoon').ui:toggle_quick_menu(require('harpoon'):list()) <CR>", 'n' },

    -- Overseer keymappings
    { "+Overseer", '<leader>o', "", 'n' },
    { "Task list", "<leader>ow", "<cmd>OverseerToggle<cr>", 'n' },
    { "Run task", "<leader>oo", "<cmd>OverseerRun<cr>", 'n' },
    { "Action recent task", "<leader>oq", "<cmd>OverseerQuickAction<cr>", 'n' },
    { "Overseer Info", "<leader>oi", "<cmd>OverseerInfo<cr>", 'n' },
    { "Task builder", "<leader>ob", "<cmd>OverseerBuild<cr>", 'n' },
    { "Task action", "<leader>ot", "<cmd>OverseerTaskAction<cr>", 'n' },
    { "Clear cache", "<leader>oc", "<cmd>OverseerClearCache<cr>", 'n' },

    -- Precognition keymappings
    { "Precognition toggle", '<leader>gp', "<cmd>lua require('precognition').toggle() <CR>", 'n' },
}
set_mappings(mappings, default_opts)


vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function()
    -- For Rust files, override <leader>a for RustLsp codeAction
    vim.keymap.set('n', '<leader>a', function() vim.cmd('RustLsp codeAction') end, 
      { buffer = true, desc = "Rust LSP Code Action" })
    
    -- Set <leader>m for RustLsp expandMacro
    vim.keymap.set('n', '<leader>m', function() vim.cmd('RustLsp expandMacro') end, 
      { buffer = true, desc = "Expand Macro in Rust" })
  end,
})
