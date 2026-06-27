vim.g.mapleader = " "
vim.g.loaded_matchit = 1

local helix = require("axelcool1234.helix")
local completion = require("axelcool1234.cmp")
local buffers = require("axelcool1234.buffers")
local gitlinker = require("axelcool1234.gitlinker")
local gh_dash = require("axelcool1234.gh_dash")
local octo = require("axelcool1234.octo")
local pickers = require("axelcool1234.pickers")
local terminal = require("axelcool1234.terminal")
local wk = require("which-key")

local function normalize_key(entry)
  local label = entry[1]
  local bind = entry[2]
  local action = entry[3]
  local mode = entry.mode or "n"
  local opts = entry.opts or {}
  local hidden = entry.hidden == true or label == "which_key_ignore"

  if hidden and action == nil then
    action = "<Nop>"
  end

  return {
    label = label,
    bind = bind,
    action = action,
    mode = mode,
    opts = opts,
    hidden = hidden,
    context = entry.context,
    expand = entry.expand,
    plugin = entry.plugin,
  }
end

local function mode_values(mode)
  if type(mode) == "table" then
    return mode
  end
  return { mode }
end

local function context_values(context)
  if context == nil then
    return nil
  end
  if type(context) == "table" then
    return context
  end
  return { context }
end

local function values_overlap(left, right)
  if left == nil or right == nil then
    return left == nil and right == nil
  end

  for _, left_value in ipairs(left) do
    if vim.tbl_contains(right, left_value) then
      return true
    end
  end

  return false
end

local function keys_share_scope(left, right)
  return values_overlap(mode_values(left.mode), mode_values(right.mode))
    and values_overlap(context_values(left.context), context_values(right.context))
end

local function has_child_key(keys, parent)
  for _, candidate in ipairs(keys) do
    if candidate.bind ~= parent.bind
      and vim.startswith(candidate.bind, parent.bind)
      and keys_share_scope(parent, candidate) then
      return true
    end
  end

  return false
end

local function normalized_keys(keys)
  local normalized = {}
  for _, entry in ipairs(keys) do
    normalized[#normalized + 1] = normalize_key(entry)
  end

  for _, key in ipairs(normalized) do
    key.group = not key.hidden
      and key.action == nil
      and (key.expand ~= nil or key.plugin ~= nil or has_child_key(normalized, key))
  end

  return normalized
end

local function add_wk_entry(entries, key, extra)
  extra = extra or {}
  local wk_entry = { key.bind }
  for field, value in pairs(extra) do
    wk_entry[field] = value
  end
  wk_entry.mode = key.mode
  wk_entry.plugin = key.plugin
  entries[#entries + 1] = wk_entry
end

local function derive_which_key_triggers(keys)
  local triggers = {}
  local seen = {}
  local group_binds = {}

  for _, key in ipairs(keys) do
    if key.context == nil and key.group then
      local modes = mode_values(key.mode)
      for _, mode in ipairs(modes) do
        group_binds[#group_binds + 1] = { bind = key.bind, mode = mode }
      end
    end
  end

  local function has_parent_group(bind, mode)
    for _, group in ipairs(group_binds) do
      if group.mode == mode and group.bind ~= bind and vim.startswith(bind, group.bind) then
        return true
      end
    end
    return false
  end

  for _, key in ipairs(keys) do
    if key.context == nil and key.group and key.opts.trigger ~= false then
      local modes = mode_values(key.mode)
      for _, mode in ipairs(modes) do
        local signature = table.concat({ mode, key.bind }, "\0")
        if not seen[signature] and not has_parent_group(key.bind, mode) then
          triggers[#triggers + 1] = { key.bind, mode = mode }
          seen[signature] = true
        end
      end
    end
  end

  return triggers
end

local function apply_global_keys(keys)
  local seen = {}

  for _, key in ipairs(keys) do
    if key.context == nil and key.action ~= nil and not key.group then
      local modes = mode_values(key.mode)
      for _, mode in ipairs(modes) do
        local signature = table.concat({ mode, key.bind }, "\0")
        if not seen[signature] then
          local final_opts = vim.tbl_extend("force", { silent = true }, key.opts, { desc = key.label })
          vim.keymap.set(mode, key.bind, key.action, final_opts)
          seen[signature] = true
        end
      end
    end
  end
end

local function add_global_which_key(keys)
  local entries = {}
  local seen = {}

  for _, key in ipairs(keys) do
    if key.context == nil then
      local modes = mode_values(key.mode)
      for _, mode in ipairs(modes) do
        local signature = table.concat({ mode, key.bind }, "\0")
        if not seen[signature] then
          if key.group then
            add_wk_entry(entries, key, { group = key.label, expand = key.expand })
          elseif key.hidden then
            add_wk_entry(entries, key, { hidden = true })
          else
            add_wk_entry(entries, key, { desc = key.label })
          end
          seen[signature] = true
        end
      end
    end
  end

  wk.add(entries)
end

local function add_hidden_keys(keys, binds, mode, context)
  for _, bind in ipairs(binds) do
    keys[#keys + 1] = { "which_key_ignore", bind, hidden = true, mode = mode, context = context }
  end
end

local function set_register_prefix_mappings()
  for _, name in ipairs(helix.register_selectable_names()) do
    vim.keymap.set("n", '"' .. name, function()
      helix.select_register(name)
    end, { silent = true, desc = "which_key_ignore" })
  end
end

local hidden_keys = {
  { binds = { "]A", "]b", "]B", "]l", "]L", "]q", "]Q", "]T", "]%", "](", "]<", "]M", "]m", "]s", "]{", "]]", "]<C-L>", "]<C-Q>", "]<C-T>" } },
  { binds = { "[A", "[b", "[B", "[l", "[L", "[q", "[Q", "[T", "[%", "[(", "[<", "[M", "[m", "[s", "[{", "[[", "[<C-L>", "[<C-Q>", "[<C-T>" } },
  { binds = { "g`", "g'", "gu", "gU", "g~", "gw", "gO", "gcc", "gR", "gx", "g%" } },
  { binds = { "<C-t>", "V" } },
  { binds = { "<BS>", "$", "0", "!", "^", "{", "}", "M", "<C-L>", "<A-n>", "<A-p>", "Y" } },
  { binds = { "<C-w>d", "<C-w><C-d>" } },
}
local keys = {
  { "Right bracket", "]" },
  { "Goto next diagnostic", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end },
  { "Goto last diagnostic", "]D", function() helix.goto_edge_diagnostic("last") end },
  { "Goto next change", "]g", function() helix.goto_change("next") end },
  { "Goto last change", "]G", function() helix.goto_change("last") end },
  { "Goto next function", "]f", function() helix.goto_textobject("function", "forward") end },
  { "Goto next type definition", "]t", function() helix.goto_textobject("class", "forward") end },
  { "Goto next parameter", "]a", function() helix.goto_textobject("parameter", "forward") end },
  { "Goto next comment", "]c", function() helix.goto_textobject("comment", "forward") end },
  { "Goto next test", "]T", function() helix.goto_textobject("test", "forward") end },
  { "Goto next pairing", "]e", function() helix.goto_textobject("entry", "forward") end },
  { "Goto next paragraph", "]p", function() helix.goto_paragraph("forward") end },
  { "Goto next (X)HTML element", "]x", function() helix.goto_textobject("xml-element", "forward") end },
  { "Add newline below", "]<Space>", function() helix.add_newline_relative(1) end },

  { "Left bracket", "[" },
  { "Goto previous diagnostic", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end },
  { "Goto first diagnostic", "[D", function() helix.goto_edge_diagnostic("first") end },
  { "Goto previous change", "[g", function() helix.goto_change("prev") end },
  { "Goto first change", "[G", function() helix.goto_change("first") end },
  { "Goto previous function", "[f", function() helix.goto_textobject("function", "backward") end },
  { "Goto previous type definition", "[t", function() helix.goto_textobject("class", "backward") end },
  { "Goto previous parameter", "[a", function() helix.goto_textobject("parameter", "backward") end },
  { "Goto previous comment", "[c", function() helix.goto_textobject("comment", "backward") end },
  { "Goto previous test", "[T", function() helix.goto_textobject("test", "backward") end },
  { "Goto previous pairing", "[e", function() helix.goto_textobject("entry", "backward") end },
  { "Goto previous paragraph", "[p", function() helix.goto_paragraph("backward") end },
  { "Goto previous (X)HTML element", "[x", function() helix.goto_textobject("xml-element", "backward") end },
  { "Add newline above", "[<Space>", function() helix.add_newline_relative(-1) end },

  { "Match", "m" },
  { "Goto matching pair", "mm", helix.goto_match },
  { "Surround add", "ms", helix.surround_add },
  { "Surround replace", "mr", helix.surround_replace },

  { "Surround delete", "md", helix.surround_delete },
  { "Nearest matching pair", "mdm", helix.surround_delete_nearest },

  { "Match around", "ma", helix.select_around_pair },
  { "Word", "maw" },
  { "WORD", "maW" },
  { "Paragraph", "map" },
  { "Indentation level", "mai" },
  { "Type definition (tree-sitter)", "mat" },
  { "Function (tree-sitter)", "maf" },
  { "Argument/parameter (tree-sitter)", "maa" },
  { "Comment (tree-sitter)", "mac" },
  { "Test (tree-sitter)", "maT" },
  { "Data structure entry (tree-sitter)", "mae" },
  { "Closest surrounding pair (tree-sitter)", "mam" },
  { "Change", "mag" },
  { "(X)HTML element (tree-sitter)", "max" },

  { "Match inside", "mi", helix.select_inside_pair },
  { "Word", "miw" },
  { "WORD", "miW" },
  { "Paragraph", "mip" },
  { "Indentation level", "mii" },
  { "Type definition (tree-sitter)", "mit" },
  { "Function (tree-sitter)", "mif" },
  { "Argument/parameter (tree-sitter)", "mia" },
  { "Comment (tree-sitter)", "mic" },
  { "Test (tree-sitter)", "miT" },
  { "Data structure entry (tree-sitter)", "mie" },
  { "Closest surrounding pair (tree-sitter)", "mim" },
  { "Change", "mig" },
  { "(X)HTML element (tree-sitter)", "mix" },

  { "Goto", "g" },
  { "Goto line number <n> else file start", "gg", helix.goto_file_start },
  { "Goto column", "g|", helix.goto_column },
  { "Goto last line", "ge", helix.goto_last_line },
  { "Goto files/URLs in selections", "gf", helix.goto_file_targets },
  { "Goto line start", "gh", helix.goto_line_start },
  { "Goto line end", "gl", helix.goto_line_end },
  { "Goto first non-blank in line", "gs", helix.goto_first_nonblank },
  { "Goto definition", "gd", pickers.definitions_picker },
  { "Goto declaration", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>" },
  { "Goto type definition", "gy", pickers.type_definitions_picker },
  { "Goto references", "gr", pickers.references_picker, opts = { nowait = true } },
  { "Goto implementation", "gi", pickers.implementations_picker },
  { "Goto window top", "gt", function() helix.goto_window_position("H") end },
  { "Goto window center", "gc", function() helix.goto_window_position("M") end },
  { "Goto window bottom", "gb", function() helix.goto_window_position("L") end },
  { "Goto last accessed file", "ga", helix.goto_last_accessed_file },
  { "Goto last modified file", "gm", helix.goto_last_modified_file },
  { "Goto next buffer", "gn", buffers.cycle_next },
  { "Goto previous buffer", "gp", buffers.cycle_prev },
  { "Show docs for item under cursor in a buffer", "gk", "<cmd>lua vim.lsp.buf.hover()<CR>" },
  { "Move down", "gj", helix.move_textual_line_down },
  { "Goto last modification", "g.", helix.goto_last_modification },

  { "Space", "<leader>" },
  { "Open file picker", "<leader>f", pickers.find_files_in_git_root },
  { "Open file picker at current working directory", "<leader>F", pickers.find_files_in_cwd },
  { "Open file explorer in workspace root", "<leader>e", pickers.open_workspace_explorer },
  { "Open file explorer at current buffer's directory", "<leader>E", pickers.open_buffer_directory_explorer },
  { "Open buffer picker", "<leader>b", pickers.buffer_picker },
  { "Open jumplist picker", "<leader>j", pickers.jumplist_picker },
  { "Open symbol picker from LSP or syntax information", "<leader>s", pickers.document_symbols_picker },
  { "Open workspace symbol picker from LSP or syntax information", "<leader>S", pickers.workspace_symbols_picker },
  { "Open diagnostic picker", "<leader>d", pickers.diagnostics_picker },
  { "Open workspace diagnostic picker", "<leader>D", pickers.workspace_diagnostics_picker },
  { "Open changed file picker", "<leader>g", pickers.changed_file_picker },
  { "Perform code action", "<leader>a", "<cmd>lua vim.lsp.buf.code_action()<CR>" },
  { "Open last picker", "<leader>'", pickers.resume_last_picker },
  { "Window", "<leader>w" },
  { "Yank selections to clipboard", "<leader>y", function() helix.yank_selection("+") end },
  { "Yank main selection to clipboard", "<leader>Y", function() helix.yank_primary_selection("+") end },
  { "Paste clipboard after selections", "<leader>p", function() helix.paste_after("+") end },
  { "Paste clipboard before selections", "<leader>P", function() helix.paste_before("+") end },
  { "Replace selections by clipboard content", "<leader>R", function() helix.replace_selection_with_yank("+") end },
  { "Global search in workspace folder", "<leader>/", pickers.live_grep_in_git_root },
  { "Show docs for item under cursor", "<leader>k", "<cmd>lua vim.lsp.buf.hover()<CR>" },
  { "Rename symbol", "<leader>r", "<cmd>lua vim.lsp.buf.rename()<CR>" },
  { "Select symbol references", "<leader>h", pickers.references_picker },
  { "Comment/uncomment selections", "<leader>c", helix.toggle_comments },
  { "Block comment/uncomment selections", "<leader>C", helix.toggle_block_comments },
  { "Line comment/uncomment selections", "<leader><A-c>", helix.toggle_line_comments },

  { "Goto next window", "<leader>ww", "<C-w>w" },
  { "Horizontal bottom split", "<leader>ws", "<cmd>botright split<CR>" },
  { "Vertical right split", "<leader>wv", "<cmd>botright vsplit<CR>" },
  { "Transpose splits", "<leader>wt", helix.transpose_splits },
  { "Goto files in selections (hsplit)", "<leader>wf", "<C-w>f" },
  { "Goto files in selections (vsplit)", "<leader>wF", "<cmd>vertical wincmd f<CR>" },
  { "Close window", "<leader>wq", "<cmd>close<CR>" },
  { "Close windows except current", "<leader>wo", "<cmd>only<CR>" },
  { "Jump to left split", "<leader>wh", "<C-w>h" },
  { "Jump to split below", "<leader>wj", "<C-w>j" },
  { "Jump to split above", "<leader>wk", "<C-w>k" },
  { "Jump to right split", "<leader>wl", "<C-w>l" },
  { "Swap with left split", "<leader>wH", function() helix.swap_with_window("h") end },
  { "Swap with split below", "<leader>wJ", function() helix.swap_with_window("j") end },
  { "Swap with split above", "<leader>wK", function() helix.swap_with_window("k") end },
  { "Swap with right split", "<leader>wL", function() helix.swap_with_window("l") end },
  { "New scratch buffer", "<leader>wn" },
  { "Horizontal bottom split scratch buffer", "<leader>wns", function() helix.new_scratch_split("horizontal") end },
  { "Vertical right split scratch buffer", "<leader>wnv", function() helix.new_scratch_split("vertical") end },
  { "Increase window height", "<leader>w+", "<cmd>resize +1<CR>" },
  { "Decrease window height", "<leader>w-", "<cmd>resize -1<CR>" },
  { "Increase window width", "<leader>w>", "<cmd>vertical resize +1<CR>" },
  { "Decrease window width", "<leader>w<", "<cmd>vertical resize -1<CR>" },
  { "Toggle focused window", "<leader>wz", helix.toggle_focus_window },

  { "Window", "<C-w>" },
  { "Goto next window", "<C-w>w", "<C-w>w" },
  { "Horizontal bottom split", "<C-w>s", "<cmd>botright split<CR>" },
  { "Vertical right split", "<C-w>v", "<cmd>botright vsplit<CR>" },
  { "Transpose splits", "<C-w>t", helix.transpose_splits },
  { "Goto files in selections (hsplit)", "<C-w>f", "<C-w>f" },
  { "Goto files in selections (vsplit)", "<C-w>F", "<cmd>vertical wincmd f<CR>" },
  { "Close window", "<C-w>q", "<cmd>close<CR>" },
  { "Close windows except current", "<C-w>o", "<cmd>only<CR>" },
  { "Jump to left split", "<C-w>h", "<C-w>h" },
  { "Jump to split below", "<C-w>j", "<C-w>j" },
  { "Jump to split above", "<C-w>k", "<C-w>k" },
  { "Jump to right split", "<C-w>l", "<C-w>l" },
  { "Swap with left split", "<C-w>H", function() helix.swap_with_window("h") end },
  { "Swap with split below", "<C-w>J", function() helix.swap_with_window("j") end },
  { "Swap with split above", "<C-w>K", function() helix.swap_with_window("k") end },
  { "Swap with right split", "<C-w>L", function() helix.swap_with_window("l") end },
  { "New scratch buffer", "<C-w>n" },
  { "Horizontal bottom split scratch buffer", "<C-w>ns", function() helix.new_scratch_split("horizontal") end },
  { "Vertical right split scratch buffer", "<C-w>nv", function() helix.new_scratch_split("vertical") end },
  { "Increase window height", "<C-w>+", "<cmd>resize +1<CR>" },
  { "Decrease window height", "<C-w>-", "<cmd>resize -1<CR>" },
  { "Increase window width", "<C-w>>", "<cmd>vertical resize +1<CR>" },
  { "Decrease window width", "<C-w><", "<cmd>vertical resize -1<CR>" },
  { "Toggle focused window", "<C-w>z", helix.toggle_focus_window },

  { "Octo", "<leader>o" },

  { "Review", "<leader>or" },
  { "Start", "<leader>ors", "<cmd>Octo review start<CR>" },
  { "Submit", "<leader>orS", "<cmd>Octo review submit<CR>" },
  { "Resume", "<leader>orr", "<cmd>Octo review resume<CR>" },
  { "Discard", "<leader>ord", "<cmd>Octo review discard<CR>" },
  { "Browse", "<leader>orb", "<cmd>Octo review browse<CR>" },
  { "Commit", "<leader>orc", "<cmd>Octo review commit<CR>" },
  { "Comments", "<leader>orC", "<cmd>Octo review comments<CR>" },
  { "Close", "<leader>orq", "<cmd>Octo review close<CR>" },
  { "Viewed", "<leader>orv", function() require("octo.mappings").toggle_viewed() end, context = { "octo.review_diff", "octo.file_panel" } },

  { "Comment", "<leader>oc" },
  { "Add", "<leader>oca", "<cmd>OctoHelixCommentAdd<CR>" },
  { "Suggest", "<leader>ocs", "<cmd>OctoHelixCommentSuggest<CR>" },
  { "Delete", "<leader>ocd", "<cmd>Octo comment delete<CR>" },
  { "URL", "<leader>ocu", "<cmd>Octo comment url<CR>" },
  { "Reply", "<leader>ocr", "<cmd>Octo comment reply<CR>" },

  { "Thread", "<leader>ot" },
  { "Resolve", "<leader>otr", "<cmd>Octo thread resolve<CR>" },
  { "Unresolve", "<leader>otu", "<cmd>Octo thread unresolve<CR>" },

  { "Reaction", "<leader>oe" },
  { "Thumbs up", "<leader>oeu", "<cmd>Octo reaction thumbs_up<CR>" },
  { "Thumbs down", "<leader>oed", "<cmd>Octo reaction thumbs_down<CR>" },
  { "Eyes", "<leader>oee", "<cmd>Octo reaction eyes<CR>" },
  { "Laugh", "<leader>oel", "<cmd>Octo reaction laugh<CR>" },
  { "Confused", "<leader>oec", "<cmd>Octo reaction confused<CR>" },
  { "Rocket", "<leader>oer", "<cmd>Octo reaction rocket<CR>" },
  { "Heart", "<leader>oeh", "<cmd>Octo reaction heart<CR>" },
  { "Party", "<leader>oep", "<cmd>Octo reaction party<CR>" },

  { "Pull Request", "<leader>op" },
  { "Checkout", "<leader>opc", "<cmd>Octo pr checkout<CR>" },
  { "Commits", "<leader>opC", "<cmd>Octo pr commits<CR>" },
  { "Changes", "<leader>oph", "<cmd>Octo pr changes<CR>" },
  { "Diff", "<leader>opd", "<cmd>Octo pr diff<CR>" },
  { "Reload", "<leader>opr", "<cmd>Octo pr reload<CR>" },
  { "Browser", "<leader>opb", "<cmd>Octo pr browser<CR>" },
  { "URL", "<leader>opu", "<cmd>Octo pr url<CR>" },

  { "GitHub", "<leader>O" },
  { "Open GitHub actions", "<leader>Oa", "<cmd>Octo<CR>" },
  { "List GitHub issues", "<leader>Oi", "<cmd>Octo issue list<CR>" },
  { "List GitHub pull requests", "<leader>Op", "<cmd>Octo pr list<CR>" },
  { "List GitHub discussions", "<leader>Od", "<cmd>Octo discussion list<CR>" },
  { "List GitHub notifications", "<leader>On", "<cmd>Octo notification list<CR>" },
  { "Search GitHub in current repo", "<leader>Os", octo.search_current_repo },
  { "Open GitHub dashboard", "<leader>OD", gh_dash.toggle },
  { "Yank git permalink", "<leader>Ol", gitlinker.copy_permalink },
  { "Open git permalink in browser", "<leader>OL", gitlinker.open_permalink },
  { "Copy repository URL", "<leader>Or", gitlinker.copy_repo_url },
  { "Open repository URL in browser", "<leader>OR", gitlinker.open_repo_url },

  { "Select register", '"', plugin = "helix_registers" },
  { "Search for regex pattern", "/", helix.search_regex },
  { "Search backward for regex pattern", "?", helix.search_regex_backward },
  { "Search selection with word boundaries", "*", helix.search_selection_detect_word_boundaries },
  { "Search selection with word boundaries", "<S-8>", helix.search_selection_detect_word_boundaries },
  { "Search selection", "<A-S-8>", helix.search_selection },

  { "Increment selections", "<C-a>", helix.increment },
  { "Decrement selections", "<C-x>", helix.decrement },

  { "Scroll half page down", "<C-d>", function() helix.scroll_half_page(1) end },
  { "Scroll half page up", "<C-u>", function() helix.scroll_half_page(-1) end },

  { "jjui", "<C-g>", terminal.open_jjui },

  { "Exit select mode", "<Esc>", helix.exit_select_mode },

  { "Left", "h", helix.normal_motion("h") },
  { "Down", "j", helix.normal_motion("j") },
  { "Up", "k", helix.normal_motion("k") },
  { "Right", "l", helix.normal_motion("l") },
  { "Find next char", "f", helix.find_char_motion("f") },
  { "Find previous char", "F", helix.find_char_motion("F") },
  { "Till next char", "t", helix.find_char_motion("t") },
  { "Till previous char", "T", helix.find_char_motion("T") },
  { "Search next", "n", function() helix.search_next("forward") end },
  { "Search previous", "N", function() helix.search_next("backward") end },
  { "Next word start", "w", function() helix.apply_word_motion("next_word_start") end },
  { "Next word end", "e", function() helix.apply_word_motion("next_word_end") end },
  { "Previous word start", "b", function() helix.apply_word_motion("prev_word_start") end },
  { "Next long word start", "W", function() helix.apply_word_motion("next_long_word_start") end },
  { "Next long word end", "E", function() helix.apply_word_motion("next_long_word_end") end },
  { "Previous long word start", "B", function() helix.apply_word_motion("prev_long_word_start") end },

  { "Change selection", "c", helix.change_selection },
  { "Change selection without yanking", "<A-c>", function() helix.change_selection("_") end },
  { "Insert before selection", "i", helix.insert_mode },
  { "Insert after selection", "a", helix.append_mode },
  { "Insert at line start", "I", helix.insert_at_line_start },
  { "Insert at line end", "A", helix.insert_at_line_end },
  { "Open line below", "o", helix.open_line_below },
  { "Open line above", "O", helix.open_line_above },
  { "Replay macro", "q", helix.replay_macro, opts = { nowait = true } },
  { "Record macro", "Q", helix.record_macro, opts = { nowait = true } },
  { "Yank selection", "y", helix.yank_selection },
  { "Paste after", "p", helix.paste_after },
  { "Paste before", "P", helix.paste_before },
  { "Replace selection with char", "r", helix.replace_selection_with_char },
  { "Replace selection with yank", "R", helix.replace_selection_with_yank },
  { "Toggle selection case", "~", helix.toggle_selection_case },
  { "Select mode", "v", helix.toggle_select_mode },
  { "Toggle comments", "<C-c>", helix.toggle_comments },
  { "Shift right", ">", helix.shift_right },
  { "Shift left", "<", helix.shift_left },
  { "Align selections", "&", helix.align_selections },

  { "Extend line below", "x", helix.extend_line_below },
  { "Select whole buffer", "%", helix.select_whole_buffer, opts = { nowait = true } },
  { "Copy selection below", "C", function() helix.copy_selection_on_adjacent_line(1) end },
  { "Copy selection above", "<A-C>", function() helix.copy_selection_on_adjacent_line(-1) end },
  { "Select regex matches", "s", helix.select_regex_matches },
  { "Split selection by line", "<A-s>", helix.split_selection_by_line },
  { "Delete", "d", helix.delete },
  { "Delete selection without yanking", "<A-d>", function() helix.delete("_") end },
  { "Trim selection", "_", helix.trim_current_preview_selection },
  { "Format selections", "=", helix.format_selections },
  { "Keep selections matching regex", "K", function() helix.filter_selections_by_regex(true) end },
  { "Remove selections matching regex", "<A-K>", function() helix.filter_selections_by_regex(false) end },
  { "Keep primary selection", ",", helix.keep_primary_selection_or_cursor },
  { "Collapse selections", ";", helix.collapse_selections_to_cursors },
  { "Flip selection direction", "<A-;>", helix.flip_selection_direction },
  { "Ensure all selections face forward", "<A-S-;>", helix.ensure_forward_selection_direction },
  { "Rotate selections backward", "(", function() helix.rotate_selections("backward") end },
  { "Rotate selections forward", ")", function() helix.rotate_selections("forward") end },
  { "Rotate selection contents backward", "<A-S-9>", function() helix.rotate_selection_contents("backward") end },
  { "Rotate selection contents forward", "<A-S-0>", function() helix.rotate_selection_contents("forward") end },

  { "Completion: Previous item", "<C-p>", completion.select_prev_item, mode = "i" },
  { "Completion: Next item", "<C-n>", completion.select_next_item, mode = "i" },
  { "Completion: Close", "<C-q>", completion.abort, mode = "i" },
  { "Completion: Accept", "<C-Space>", completion.confirm, mode = "i" },
  { "Snippet: Jump Forward (else Tab)", "<Tab>", completion.jump_forward, mode = { "i", "s" }, opts = { expr = false } },
  { "Snippet: Jump Backward (else Shift-Tab)", "<S-Tab>", completion.jump_backward, mode = { "i", "s" }, opts = { expr = false } },

  { "Previous buffer", "H", buffers.cycle_prev },
  { "Next buffer", "L", buffers.cycle_next },
  { "Close the current buffer.", "gq", buffers.close_current_buffer },
  { "Close the current buffer forcefully, ignoring unsaved changes.", "gQ", function() buffers.close_current_buffer(true) end },

  { "Undo", "u", helix.undo },
  { "Redo", "U", helix.redo },
  { "Flash jump", "z", helix.flash_jump, opts = { nowait = true } },
  { "Goto line", "G", helix.goto_line },

  { "Repeat last motion", "<A-.>", helix.repeat_last_motion },

  { "File explorer", "-", pickers.open_buffer_directory_explorer },

  { "Octo goto backing file", "gF", function() require("octo.navigation").go_to_file() end, context = { "octo.review_diff", "octo.pull_request" } },
  { "Octo goto previous comment", "[c", function() require("octo.navigation").prev_comment() end, context = { "octo.review_thread", "octo.pull_request", "octo.issue", "octo.discussion" } },
  { "Octo goto next comment", "]c", function() require("octo.navigation").next_comment() end, context = { "octo.review_thread", "octo.pull_request", "octo.issue", "octo.discussion" } },
  { "Octo goto previous thread", "[t", function() require("octo.mappings").prev_thread() end, context = "octo.review_diff" },
  { "Octo goto next thread", "]t", function() require("octo.mappings").next_thread() end, context = "octo.review_diff" },
  { "Octo goto previous thread", "[t", octo.goto_previous_thread, context = "octo.pull_request" },
  { "Octo goto next thread", "]t", octo.goto_next_thread, context = "octo.pull_request" },
  { "Octo select previous changed file", "[q", function() require("octo.mappings").select_prev_entry() end, context = { "octo.review_thread", "octo.review_diff", "octo.file_panel" } },
  { "Octo select next changed file", "]q", function() require("octo.mappings").select_next_entry() end, context = { "octo.review_thread", "octo.review_diff", "octo.file_panel" } },
  { "Octo select first changed file", "[Q", function() require("octo.mappings").select_first_entry() end, context = { "octo.review_thread", "octo.review_diff", "octo.file_panel" } },
  { "Octo select last changed file", "]Q", function() require("octo.mappings").select_last_entry() end, context = { "octo.review_thread", "octo.review_diff", "octo.file_panel" } },
  { "Octo select previous unviewed file", "[u", function() require("octo.mappings").select_prev_unviewed_entry() end, context = { "octo.review_thread", "octo.review_diff", "octo.file_panel" } },
  { "Octo select next unviewed file", "]u", function() require("octo.mappings").select_next_unviewed_entry() end, context = { "octo.review_thread", "octo.review_diff", "octo.file_panel" } },
}

for _, hidden in ipairs(hidden_keys) do
  add_hidden_keys(keys, hidden.binds, hidden.mode, hidden.context)
end

local normalized = normalized_keys(keys)

_G.axelcool1234_which_key_triggers = derive_which_key_triggers(normalized)

apply_global_keys(normalized)
octo.setup_buffer_mappings(normalized)
set_register_prefix_mappings()
add_global_which_key(normalized)
helix.setup_autocmds()
