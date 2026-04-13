vim.g.mapleader = " "
vim.g.loaded_matchit = 1

local helix = require("axelcool1234.helix")
local pickers = require("axelcool1234.pickers")
local wk = require("which-key")

local function goto_edge_diagnostic(edge)
  local diagnostics = vim.diagnostic.get(0)
  if #diagnostics == 0 then
    vim.notify("No diagnostics in current buffer", vim.log.levels.INFO)
    return
  end

  table.sort(diagnostics, function(left, right)
    if left.lnum == right.lnum then
      return left.col < right.col
    end
    return left.lnum < right.lnum
  end)

  local diagnostic = edge == "last" and diagnostics[#diagnostics] or diagnostics[1]
  vim.api.nvim_win_set_cursor(0, { diagnostic.lnum + 1, diagnostic.col })
  vim.diagnostic.open_float()
end

local function read_first_line(path)
  local handle = io.open(path, "r")
  if not handle then
    return nil
  end

  local line = handle:read("*l")
  handle:close()
  return line
end

local function edit_if_selected(path)
  local selected = read_first_line(path)
  os.remove(path)

  if selected and selected ~= "" then
    vim.cmd.edit(vim.fn.fnameescape(selected))
  end
end

local function has_command(command)
  if vim.fn.executable(command) == 1 then
    return true
  end

  vim.notify(command .. " is not available in PATH", vim.log.levels.WARN)
  return false
end

local function run_terminal_tab(command, opts)
  opts = opts or {}

  if opts.write_all ~= false then
    vim.cmd("silent! writeall")
  end

  vim.cmd("tabnew")
  local tabpage = vim.api.nvim_get_current_tabpage()

  vim.fn.termopen(command, {
    env = opts.env,
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_tabpage_is_valid(tabpage) then
          vim.api.nvim_set_current_tabpage(tabpage)
          vim.cmd("silent! tabclose")
        end

        if opts.on_exit then
          opts.on_exit()
        end
      end)
    end,
  })

  vim.cmd("startinsert")
end

local function open_lazygit()
  if not has_command("lazygit") then
    return
  end

  local path_file = vim.fn.tempname()
  os.remove(path_file)

  run_terminal_tab({ "lazygit" }, {
    env = { LAZYGIT_OPEN_PATH_FILE = path_file },
    on_exit = function()
      edit_if_selected(path_file)
      vim.cmd("checktime")
    end,
  })
end

local function set_mappings(mappings, default_opts)
  for _, mapping in ipairs(mappings) do
    local desc, lhs, rhs, modes, opts = unpack(mapping)
    opts = opts or {}
    modes = type(modes) == "table" and modes or { modes }

    for _, mode in ipairs(modes) do
      local final_opts = vim.tbl_extend("force", default_opts, opts, { desc = desc })
      vim.keymap.set(mode, lhs, rhs, final_opts)
    end
  end
end

local function set_register_prefix_mappings()
  for _, name in ipairs(helix.register_selectable_names()) do
    vim.keymap.set("n", '"' .. name, function()
      helix.select_register(name)
    end, { silent = true, desc = "which_key_ignore" })
  end
end

local function add_register_which_key()
  wk.add({
    {
      '"',
      group = "Select register",
      mode = "n",
      expand = function()
        return helix.which_key_registers()
      end,
    },
  })
end

local default_opts = { silent = true }
local mappings = {
  { "Open file picker", "<leader>f", pickers.find_files_in_git_root, "n" },
  { "Open file picker at current working directory", "<leader>F", pickers.find_files_in_cwd, "n" },
  { "Open file explorer in workspace root", "<leader>e", pickers.open_workspace_explorer, "n" },
  { "Open file explorer at current buffer's directory", "<leader>E", pickers.open_buffer_directory_explorer, "n" },
  { "Open buffer picker", "<leader>b", pickers.buffer_picker, "n" },
  { "Open jumplist picker", "<leader>j", pickers.jumplist_picker, "n" },
  { "Open symbol picker from LSP or syntax information", "<leader>s", pickers.document_symbols_picker, "n" },
  { "Open workspace symbol picker from LSP or syntax information", "<leader>S", pickers.workspace_symbols_picker, "n" },
  { "Open diagnostic picker", "<leader>d", pickers.diagnostics_picker, "n" },
  { "Open workspace diagnostic picker", "<leader>D", pickers.workspace_diagnostics_picker, "n" },
  { "Perform code action", "<leader>a", "<cmd>lua vim.lsp.buf.code_action()<CR>", "n" },
  { "Open last picker", "<leader>'", pickers.resume_last_picker, "n" },
  { "Window", "<leader>w", "", "n" },
  { "Yank selections to clipboard", "<leader>y", function() helix.yank_selection("+") end, "n" },
  { "Yank main selection to clipboard", "<leader>Y", function() helix.yank_primary_selection("+") end, "n" },
  { "Paste clipboard after selections", "<leader>p", function() helix.paste_after("+") end, "n" },
  { "Paste clipboard before selections", "<leader>P", function() helix.paste_before("+") end, "n" },
  { "Replace selections by clipboard content", "<leader>R", function() helix.replace_selection_with_yank("+") end, "n" },
  { "Global search in workspace folder", "<leader>/", pickers.live_grep_in_git_root, "n" },
  { "Show docs for item under cursor", "<leader>k", "<cmd>lua vim.lsp.buf.hover()<CR>", "n" },
  { "Rename symbol", "<leader>r", "<cmd>lua vim.lsp.buf.rename()<CR>", "n" },
  { "Select symbol references", "<leader>h", pickers.references_picker, "n" },

  { "Search for regex pattern", "/", helix.search_regex, "n" },
  { "Search backward for regex pattern", "?", helix.search_regex_backward, "n" },

  { "Paste after", "p", helix.paste_after, "n" },
  { "Paste before", "P", helix.paste_before, "n" },

  { "Replace", "gR", '<cmd>normal! "_d0P"<CR>', "n" },

  { "Scroll half page down", "<C-d>", function() helix.scroll_half_page(1) end, "n" },
  { "Scroll half page up", "<C-u>", function() helix.scroll_half_page(-1) end, "n" },

  { "Lazygit", "<C-g>", open_lazygit, "n" },

  { "Exit select mode", "<Esc>", helix.exit_select_mode, "n" },

  { "Left", "h", helix.normal_motion("h"), "n" },
  { "Down", "j", helix.normal_motion("j"), "n" },
  { "Up", "k", helix.normal_motion("k"), "n" },
  { "Right", "l", helix.normal_motion("l"), "n" },
  { "Find next char", "f", helix.find_char_motion("f"), "n" },
  { "Find previous char", "F", helix.find_char_motion("F"), "n" },
  { "Till next char", "t", helix.find_char_motion("t"), "n" },
  { "Till previous char", "T", helix.find_char_motion("T"), "n" },
  { "Search next", "n", function() helix.search_next("forward") end, "n" },
  { "Search previous", "N", function() helix.search_next("backward") end, "n" },
  { "Next word start", "w", function() helix.apply_word_motion("next_word_start") end, "n" },
  { "Next word end", "e", function() helix.apply_word_motion("next_word_end") end, "n" },
  { "Previous word start", "b", function() helix.apply_word_motion("prev_word_start") end, "n" },
  { "Next long word start", "W", function() helix.apply_word_motion("next_long_word_start") end, "n" },
  { "Next long word end", "E", function() helix.apply_word_motion("next_long_word_end") end, "n" },
  { "Previous long word start", "B", function() helix.apply_word_motion("prev_long_word_start") end, "n" },

  { "Change selection", "c", helix.change_selection, "n" },
  { "Change selection without yanking", "<A-c>", function() helix.change_selection("_") end, "n" },
  { "Insert before selection", "i", helix.insert_mode, "n" },
  { "Insert after selection", "a", helix.append_mode, "n" },
  { "Insert at line start", "I", helix.insert_at_line_start, "n" },
  { "Insert at line end", "A", helix.insert_at_line_end, "n" },
  { "Open line below", "o", helix.open_line_below, "n" },
  { "Open line above", "O", helix.open_line_above, "n" },
  { "Yank selection", "y", helix.yank_selection, "n" },
  { "Replace selection with char", "r", helix.replace_selection_with_char, "n" },
  { "Replace selection with yank", "R", helix.replace_selection_with_yank, "n" },
  { "Toggle selection case", "~", helix.toggle_selection_case, "n" },
  { "Select mode", "v", helix.toggle_select_mode, "n" },
  { "Shift right", ">", helix.shift_right, "n" },
  { "Shift left", "<", helix.shift_left, "n" },

  { "Extend line below", "x", helix.extend_line_below, "n" },
  { "Select whole buffer", "%", helix.select_whole_buffer, "n", { nowait = true } },
  { "None", "$", "<Nop>", "n" },
  { "Copy selection below", "C", function() helix.copy_selection_on_adjacent_line(1) end, "n" },
  { "Copy selection above", "<A-C>", function() helix.copy_selection_on_adjacent_line(-1) end, "n" },
  { "Select regex matches", "s", helix.select_regex_matches, "n" },
  { "Split selection by line", "<A-s>", helix.split_selection_by_line, "n" },
  { "Delete", "d", helix.delete, "n" },
  { "Delete selection without yanking", "<A-d>", function() helix.delete("_") end, "n" },
  { "Trim selection", "_", helix.trim_current_preview_selection, "n" },
  { "Keep selections matching regex", "K", function() helix.filter_selections_by_regex(true) end, "n" },
  { "Remove selections matching regex", "<A-K>", function() helix.filter_selections_by_regex(false) end, "n" },
  { "Keep primary selection", ",", helix.keep_primary_selection_or_cursor, "n" },
  { "Collapse selections", ";", helix.collapse_selections_to_cursors, "n" },
  { "Flip selection direction", "<A-;>", helix.flip_selection_direction, "n" },
  { "Ensure all selections face forward", "<A-S-;>", helix.ensure_forward_selection_direction, "n" },

  { "Goto matching pair", "mm", helix.goto_match, "n" },
  { "Surround add", "ms", helix.surround_add, "n" },
  { "Select around surround", "ma", helix.select_around_pair, "n" },
  { "Select inside surround", "mi", helix.select_inside_pair, "n" },
  { "Surround delete", "md", helix.surround_delete, "n" },
  { "Surround replace", "mr", helix.surround_replace, "n" },
  { "Surround delete nearest", "mdm", helix.surround_delete_nearest, "n" },

  { "Goto file start", "gg", helix.goto_file_start, "n" },
  { "Goto column", "g|", helix.goto_column, "n" },
  { "Goto last line", "ge", helix.goto_last_line, "n" },
  { "Goto files or URLs in selections", "gf", helix.goto_file_targets, "n" },
  { "Goto line start", "gh", helix.goto_line_start, "n" },
  { "Goto line end", "gl", helix.goto_line_end, "n" },
  { "Goto first non-blank in line", "gs", helix.goto_first_nonblank, "n" },
  { "Goto line", "G", helix.goto_line, "n" },
  { "Undo", "u", helix.undo, "n" },
  { "Redo", "U", helix.redo, "n" },
  { "Goto window top", "gt", function() helix.goto_window_position("H") end, "n" },
  { "Goto window center", "gc", function() helix.goto_window_position("M") end, "n" },
  { "Goto window bottom", "gb", function() helix.goto_window_position("L") end, "n" },

  { "Move through diagnostic (prev)", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "n" },
  { "Move through diagnostic (next)", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "n" },
  { "Goto first diagnostic", "[D", function() goto_edge_diagnostic("first") end, "n" },
  { "Goto last diagnostic", "]D", function() goto_edge_diagnostic("last") end, "n" },
  { "Goto previous change", "[g", function() helix.goto_change("prev") end, "n" },
  { "Goto next change", "]g", function() helix.goto_change("next") end, "n" },
  { "Goto first change", "[G", function() helix.goto_change("first") end, "n" },
  { "Goto last change", "]G", function() helix.goto_change("last") end, "n" },
  { "Goto previous function", "[f", function() helix.goto_textobject("function", "backward") end, "n" },
  { "Goto next function", "]f", function() helix.goto_textobject("function", "forward") end, "n" },
  { "Goto previous type definition", "[t", function() helix.goto_textobject("class", "backward") end, "n" },
  { "Goto next type definition", "]t", function() helix.goto_textobject("class", "forward") end, "n" },
  { "Goto previous parameter", "[a", function() helix.goto_textobject("parameter", "backward") end, "n" },
  { "Goto next parameter", "]a", function() helix.goto_textobject("parameter", "forward") end, "n" },
  { "Goto previous comment", "[c", function() helix.goto_textobject("comment", "backward") end, "n" },
  { "Goto next comment", "]c", function() helix.goto_textobject("comment", "forward") end, "n" },
  { "Goto previous pairing", "[e", function() helix.goto_textobject("entry", "backward") end, "n" },
  { "Goto next pairing", "]e", function() helix.goto_textobject("entry", "forward") end, "n" },
  { "Goto previous paragraph", "[p", function() helix.goto_paragraph("backward") end, "n" },
  { "Goto next paragraph", "]p", function() helix.goto_paragraph("forward") end, "n" },
  { "Goto previous (X)HTML element", "[x", function() helix.goto_textobject("xml-element", "backward") end, "n" },
  { "Goto next (X)HTML element", "]x", function() helix.goto_textobject("xml-element", "forward") end, "n" },
  { "Add newline above", "[<Space>", function() helix.add_newline_relative(-1) end, "n" },
  { "Add newline below", "]<Space>", function() helix.add_newline_relative(1) end, "n" },
  { "which_key_ignore", "[A", "<Nop>", "n" },
  { "which_key_ignore", "]A", "<Nop>", "n" },
  { "which_key_ignore", "[b", "<Nop>", "n" },
  { "which_key_ignore", "]b", "<Nop>", "n" },
  { "which_key_ignore", "[B", "<Nop>", "n" },
  { "which_key_ignore", "]B", "<Nop>", "n" },
  { "which_key_ignore", "[l", "<Nop>", "n" },
  { "which_key_ignore", "]l", "<Nop>", "n" },
  { "which_key_ignore", "[L", "<Nop>", "n" },
  { "which_key_ignore", "]L", "<Nop>", "n" },
  { "which_key_ignore", "[q", "<Nop>", "n" },
  { "which_key_ignore", "]q", "<Nop>", "n" },
  { "which_key_ignore", "[Q", "<Nop>", "n" },
  { "which_key_ignore", "]Q", "<Nop>", "n" },
  { "which_key_ignore", "[T", "<Nop>", "n" },
  { "which_key_ignore", "]T", "<Nop>", "n" },
  { "which_key_ignore", "[%", "<Nop>", "n" },
  { "which_key_ignore", "]%", "<Nop>", "n" },
  { "which_key_ignore", "[(", "<Nop>", "n" },
  { "which_key_ignore", "](", "<Nop>", "n" },
  { "which_key_ignore", "[<", "<Nop>", "n" },
  { "which_key_ignore", "]<", "<Nop>", "n" },
  { "which_key_ignore", "[M", "<Nop>", "n" },
  { "which_key_ignore", "]M", "<Nop>", "n" },
  { "which_key_ignore", "[m", "<Nop>", "n" },
  { "which_key_ignore", "]m", "<Nop>", "n" },
  { "which_key_ignore", "[s", "<Nop>", "n" },
  { "which_key_ignore", "]s", "<Nop>", "n" },
  { "which_key_ignore", "[{", "<Nop>", "n" },
  { "which_key_ignore", "]{", "<Nop>", "n" },
  { "which_key_ignore", "[<C-L>", "<Nop>", "n" },
  { "which_key_ignore", "]<C-L>", "<Nop>", "n" },
  { "which_key_ignore", "[<C-Q>", "<Nop>", "n" },
  { "which_key_ignore", "]<C-Q>", "<Nop>", "n" },
  { "which_key_ignore", "[<C-T>", "<Nop>", "n" },
  { "which_key_ignore", "]<C-T>", "<Nop>", "n" },

  { "Goto declaration", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", "n" },
  { "Goto Definition", "gd", '<cmd>lua require("telescope.builtin").lsp_definitions({ reuse_win = true })<CR>', "n" },
  { "Goto Implementation", "gi", '<cmd>lua require("telescope.builtin").lsp_implementations({ reuse_win = true })<CR>', "n" },
  { "Goto Type Definition", "gy", '<cmd>lua require("telescope.builtin").lsp_type_definitions({ reuse_win = true })<CR>', "n" },
  { "References", "gr", "<cmd>Telescope lsp_references<CR>", "n", { nowait = true } },

  { "Goto last accessed file", "ga", helix.goto_last_accessed_file, "n" },
  { "Goto last modified file", "gm", helix.goto_last_modified_file, "n" },
  { "Goto next buffer", "gn", "<cmd>BufferLineCycleNext<CR>", "n" },
  { "Goto previous buffer", "gp", "<cmd>BufferLineCyclePrev<CR>", "n" },
  { "Hover", "gk", "<cmd>lua vim.lsp.buf.hover()<CR>", "n" },
  { "Move down textual line", "gj", helix.move_textual_line_down, "n" },
  { "Goto last modification", "g.", helix.goto_last_modification, "n" },
  { "which_key_ignore", "g`", "<Nop>", "n" },
  { "which_key_ignore", "g'", "<Nop>", "n" },
  { "which_key_ignore", "gu", "<Nop>", "n" },
  { "which_key_ignore", "gU", "<Nop>", "n" },
  { "which_key_ignore", "g~", "<Nop>", "n" },
  { "which_key_ignore", "gw", "<Nop>", "n" },
  { "which_key_ignore", "gO", "<Nop>", "n" },
  { "which_key_ignore", "gcc", "<Nop>", "n" },
  { "which_key_ignore", "gR", "<Nop>", "n" },
  { "which_key_ignore", "gx", "<Nop>", "n" },
  { "which_key_ignore", "g%", "<Nop>", "n" },
  { "Completion: Previous item", "<C-p>", "<cmd>lua require('cmp').select_prev_item()<CR>", "i" },
  { "Completion: Next item", "<C-n>", "<cmd>lua require('cmp').select_next_item()<CR>", "i" },
  { "Completion: Close", "<C-e>", "<cmd>lua require('cmp').close()<CR>", "i" },
  { "Completion: Accept", "<C-Space>", "<cmd>lua require('cmp').confirm({ select = true })<CR>", "i" },

  { "UltiSnips: Expand Trigger", "<tab>", "<cmd>call UltiSnips#ExpandSnippet()<CR>", { "i", "s" } },
  { "UltiSnips: Jump Forward", "<Up>", "<cmd>call UltiSnips#JumpForwards()<CR>", { "i", "s" } },
  { "UltiSnips: Jump Backward", "<Down>", "<cmd>call UltiSnips#JumpBackwards()<CR>", { "i", "s" } },

  { "Previous buffer", "H", "<cmd>BufferLineCyclePrev<CR>", "n" },
  { "Next buffer", "L", "<cmd>BufferLineCycleNext<CR>", "n" },
  { "Close Buffer", "gq", "<cmd>bdelete<CR>", "n" },
  { "Close Buffer Force", "gQ", "<cmd>bdelete!<CR>", "n" },

  { "Window left", "<leader>wh", "<C-w>h", "n" },
  { "Window down", "<leader>wj", "<C-w>j", "n" },
  { "Window up", "<leader>wk", "<C-w>k", "n" },
  { "Window right", "<leader>wl", "<C-w>l", "n" },
  { "Next window", "<leader>ww", "<C-w>w", "n" },
  { "Horizontal split", "<leader>ws", "<C-w>s", "n" },
  { "Vertical split", "<leader>wv", "<C-w>v", "n" },
  { "Close window", "<leader>wq", "<C-w>q", "n" },
  { "Only window", "<leader>wo", "<C-w>o", "n" },
  { "Open file in split", "<leader>wf", "<C-w>f", "n" },
  { "Open file in vertical split", "<leader>wF", "<cmd>vertical wincmd f<CR>", "n" },

  { "File explorer", "-", pickers.open_buffer_directory_explorer, "n" },

  { "None", "<C-t>", "", "n" },
  { "None", "V", "<Nop>", "n" },
}

set_mappings(mappings, default_opts)
set_register_prefix_mappings()
add_register_which_key()
helix.setup_autocmds()
