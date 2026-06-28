local helix = require("axelcool1234.helix")
local state_module = require("axelcool1234.helix.state")

local function assert_equal(actual, expected, label)
  if not vim.deep_equal(actual, expected) then
    error(label .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual))
  end
end

local function reset_case(lines, row, col0)
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "xt", false)
  vim.wait(50)
  vim.cmd("enew!")
  vim.bo.filetype = "text"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { row, col0 })
end

local function with_fresh_jumplist_tab(run)
  vim.cmd("tabnew")
  local ok, err = xpcall(run, debug.traceback)
  vim.cmd("tabclose!")
  if not ok then
    error(err)
  end
end

local function jumplist_items()
  return helix.jumplist_items()
end

local function assert_jumplist_push(reason, label, action)
  local before = jumplist_items()
  action()
  local after = jumplist_items()
  assert_equal(#after, #before + 1, label .. " should add one jumplist entry")
  assert_equal(after[1].reason, reason, label .. " should record the expected jumplist reason")
end

local function with_stubbed_input(value, run)
  local original_input = vim.fn.input
  vim.fn.input = function()
    return value
  end

  local ok, err = xpcall(run, debug.traceback)
  vim.fn.input = original_input
  if not ok then
    error(err)
  end
end

local function with_stubbed_getcharstr(values, run)
  local original_getcharstr = vim.fn.getcharstr
  local queue = type(values) == "table" and vim.deepcopy(values) or { values }
  vim.fn.getcharstr = function()
    local next_value = queue[1]
    table.remove(queue, 1)
    return next_value
  end

  local ok, err = xpcall(run, debug.traceback)
  vim.fn.getcharstr = original_getcharstr
  if not ok then
    error(err)
  end
end

local function start_treesitter(filetype)
  vim.bo.filetype = filetype
  pcall(vim.treesitter.start, 0, filetype)
end

local function all_cursor_positions()
  local primary = vim.api.nvim_win_get_cursor(0)
  local positions = { { primary[1], primary[2] + 1 } }
  local ns = vim.api.nvim_get_namespaces()["axelcool1234-helix-cursor"]
  if not ns then
    return positions
  end

  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do
    positions[#positions + 1] = { mark[2] + 1, mark[3] + 1 }
  end

  table.sort(positions, function(left, right)
    if left[1] == right[1] then
      return left[2] < right[2]
    end
    return left[1] < right[1]
  end)

  return positions
end

local function primary_selection_range()
  local ns = vim.api.nvim_get_namespaces()["axelcool1234-helix-selection"]
  if not ns then
    return nil
  end

  local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
  if #marks == 0 then
    return nil
  end

  local mark = marks[1]
  return {
    start_row = mark[2] + 1,
    start_col = mark[3] + 1,
    end_row = mark[4].end_row + 1,
    end_col = mark[4].end_col,
  }
end

local function current_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function capture_echo(thunk, wait_ms)
  local original = vim.api.nvim_echo
  local seen = {}

  vim.api.nvim_echo = function(chunks, history, opts)
    local parts = {}
    for _, chunk in ipairs(chunks or {}) do
      parts[#parts + 1] = chunk[1]
    end
    seen[#seen + 1] = table.concat(parts, "")
    return original(chunks, history, opts)
  end

  local ok, result = pcall(thunk)
  if wait_ms and wait_ms > 0 then
    vim.wait(wait_ms)
  end
  vim.api.nvim_echo = original
  if not ok then
    error(result)
  end

  return seen, result
end

local function feed(keys)
  local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(termcodes, "xt", false)
  vim.wait(150)
end

local function feed_deferred(keys, delay_ms, wait_ms)
  local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.defer_fn(function()
    vim.api.nvim_feedkeys(termcodes, "xt", false)
  end, delay_ms or 20)
  vim.wait(wait_ms or 400)
end

local function selection_texts()
  local ns = vim.api.nvim_get_namespaces()["axelcool1234-helix-selection"]
  if not ns then
    return {}
  end

  local texts = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
    local pieces = vim.api.nvim_buf_get_text(0, mark[2], mark[3], mark[4].end_row, mark[4].end_col, {})
    texts[#texts + 1] = table.concat(pieces, "\n")
  end

  return texts
end

local function which_key_entry(name)
  for _, entry in ipairs(helix.which_key_registers()) do
    if entry[1] == name then
      return entry
    end
  end

  return nil
end

local function which_key_item(name)
  for _, item in ipairs(helix.which_key_register_items()) do
    if item.key == name then
      return item
    end
  end

  return nil
end

local function leave_single_preview_active()
  helix.toggle_select_mode()
  helix.toggle_select_mode()
end

local cases = {
  {
    name = "j updates single preview instead of sticking",
    run = function()
      reset_case({ "one", "two", "three" }, 1, 0)
      leave_single_preview_active()
      helix.normal_motion("j")()
      helix.normal_motion("j")()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 3, 0 }, "j should keep advancing from the current row")
    end,
  },
  {
    name = "unicode h and l move by symbol not utf8 byte",
    run = function()
      reset_case({ "∀βx" }, 1, 0)

      helix.normal_motion("l")()
      assert_equal(state_module.current_pos_1indexed(), { 1, 2 }, "first l should move across the whole ∀ symbol")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 3 }, "real cursor should land on the next symbol byte offset")

      helix.normal_motion("l")()
      assert_equal(state_module.current_pos_1indexed(), { 1, 3 }, "second l should move across the whole β symbol")

      helix.normal_motion("h")()
      assert_equal(state_module.current_pos_1indexed(), { 1, 2 }, "h should move back across the whole β symbol")
    end,
  },
  {
    name = "delete removes whole unicode symbol",
    run = function()
      reset_case({ "∀x" }, 1, 0)

      helix.delete()

      assert_equal(current_lines(), { "x" }, "delete should remove the full ∀ symbol instead of corrupting its bytes")
      assert_equal(state_module.current_pos_1indexed(), { 1, 1 }, "cursor should remain at the start of the surviving text")
    end,
  },
  {
    name = "delete unicode subscript keeps cursor at surviving token edge",
    run = function()
      reset_case({ "axiom OperationPtr.dominates (op₁ op₂ : OperationPtr) (ctx : WfIRContext OpInfo) : Prop" }, 1, 0)
      state_module.move_cursor_to_pos({ 1, 37 })
      helix.toggle_select_mode()
      helix.delete()

      assert_equal(
        current_lines(),
        { "axiom OperationPtr.dominates (op₁ op : OperationPtr) (ctx : WfIRContext OpInfo) : Prop" },
        "deleting the unicode subscript should only remove that symbol"
      )
      assert_equal(
        state_module.current_pos_1indexed(),
        { 1, 37 },
        "cursor should stay right after the surviving 'op' token after deleting the unicode subscript"
      )
    end,
  },
  {
    name = "inserting before unicode selection exits at true insertion endpoint",
    run = function()
      reset_case({ "(∀x)" }, 1, 1)
      feed("mim")
      helix.insert_mode()
      vim.wait(50)

      local row, col0 = unpack(vim.api.nvim_win_get_cursor(0))
      vim.api.nvim_buf_set_text(0, row - 1, col0, row - 1, col0, { "hello" })
      vim.cmd("stopinsert")
      vim.wait(100)

      assert_equal(current_lines(), { "(hello∀x)" }, "inserting before a unicode selection should preserve the selected text")
      assert_equal(state_module.current_pos_1indexed(), { 1, 7 }, "cursor should stay at the end of the inserted text after leaving insert mode")
    end,
  },
  {
    name = "insert_mode uses updated row after vertical motion",
    run = function()
      reset_case({ "one", "two", "three" }, 1, 0)
      leave_single_preview_active()
      helix.normal_motion("j")()
      helix.normal_motion("j")()
      helix.insert_mode()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 3, 0 }, "insert should start on the moved row")
      vim.cmd("stopinsert")
    end,
  },
  {
    name = "backspace in multi-insert deletes at every cursor",
    run = function()
      reset_case({ "abc", "abc" }, 1, 3)
      helix.copy_selection_on_adjacent_line(1)
      helix.insert_mode()

      local backspace_map = vim.fn.maparg("<BS>", "i", false, true)
      assert(type(backspace_map.callback) == "function", "multi-insert should install a buffer-local insert backspace handler")
      backspace_map.callback()
      vim.wait(100)
      vim.cmd("stopinsert")
      vim.wait(100)

      assert_equal(current_lines(), { "ab", "ab" }, "backspace in multi-insert should delete before every active cursor")
      assert_equal(all_cursor_positions(), { { 1, 3 }, { 2, 3 } }, "escaping multi-insert backspace should keep both cursors aligned")
    end,
  },
  {
    name = "normal mode backspace is unmapped to a no-op",
    run = function()
      local backspace_map = vim.fn.maparg("<BS>", "n", false, true)
      assert_equal(backspace_map.rhs, "<Nop>", "normal mode backspace should be explicitly disabled")
    end,
  },
  {
    name = "open_line_below keeps cursor at insertion endpoint on escape",
    run = function()
      reset_case({ "abc" }, 1, 3)
      helix.open_line_below()
      feed_deferred("xyz<Esc>")
      assert_equal(current_lines(), { "abc", "yz" }, "open_line_below should preserve the inserted text in headless mode")
      assert_equal(state_module.current_pos_1indexed(), { 2, 3 }, "escaping o should keep the cursor at the insertion endpoint")
    end,
  },
  {
    name = "open_line_above keeps cursor at insertion endpoint on escape",
    run = function()
      reset_case({ "abc" }, 1, 3)
      helix.open_line_above()
      vim.wait(50)
      vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { "up" })
      vim.cmd("stopinsert")
      vim.wait(100)
      assert_equal(current_lines(), { "up", "abc" }, "open_line_above should preserve the inserted text in headless mode")
      assert_equal(state_module.current_pos_1indexed(), { 1, 3 }, "escaping O should keep the cursor at the insertion endpoint")
    end,
  },
  {
    name = "copy_selection_on_adjacent_line skips short line for same-column clone",
    run = function()
      reset_case({ "12345", "1", "12345" }, 1, 4)
      helix.copy_selection_on_adjacent_line(1)
      assert_equal(all_cursor_positions(), { { 1, 5 }, { 3, 5 } }, "first C should skip the short line and clone to the nearest same-column line")
    end,
  },
  {
    name = "copy_selection_on_adjacent_line from skipped clone continues searching",
    run = function()
      reset_case({ "12345", "1", "12345", "12345" }, 1, 4)
      helix.copy_selection_on_adjacent_line(1)
      helix.copy_selection_on_adjacent_line(1)
      assert_equal(all_cursor_positions(), { { 1, 5 }, { 3, 5 }, { 4, 5 } }, "second C should keep searching for the next same-column line")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 4, 4 }, "the newest same-column clone should become the primary cursor")
    end,
  },
  {
    name = "copy_selection_on_adjacent_line upward makes upper clone primary",
    run = function()
      reset_case({ "11111", "22222", "33333" }, 2, 4)
      helix.copy_selection_on_adjacent_line(-1)
      assert_equal(all_cursor_positions(), { { 1, 5 }, { 2, 5 } }, "alt-C should create a cursor above while keeping the original selection")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 4 }, "the new upper clone should become the primary cursor")
    end,
  },
  {
    name = "copy_selection_on_adjacent_line respects counts in both directions",
    run = function()
      reset_case({ "11111", "22222", "33333", "44444", "55555" }, 2, 4)
      helix.copy_selection_on_adjacent_line(1, 2)
      assert_equal(all_cursor_positions(), { { 2, 5 }, { 3, 5 }, { 4, 5 } }, "2C should create two new clones below")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 4, 4 }, "counted C should make the newest lower clone primary")

      reset_case({ "11111", "22222", "33333", "44444", "55555" }, 4, 4)
      helix.copy_selection_on_adjacent_line(-1, 2)
      assert_equal(all_cursor_positions(), { { 2, 5 }, { 3, 5 }, { 4, 5 } }, "2 alt-C should create two new clones above")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 4 }, "counted alt-C should make the newest upper clone primary")
    end,
  },
  {
    name = "adjacent regex matches stay as separate cursors",
    run = function()
      reset_case({ "aaaaa" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("a")
      assert_equal(
        all_cursor_positions(),
        { { 1, 1 }, { 1, 2 }, { 1, 3 }, { 1, 4 }, { 1, 5 } },
        "adjacent single-character matches should not merge into one cursor"
      )
    end,
  },
  {
    name = "unicode regex match deletes whole symbol",
    run = function()
      reset_case({ "∀x" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("∀")
      helix.delete()
      assert_equal(current_lines(), { "x" }, "unicode regex selection should target only the matched symbol")
      assert_equal(state_module.current_pos_1indexed(), { 1, 1 }, "cursor should stay at the start of the remaining text after deleting a unicode regex match")
    end,
  },
  {
    name = "incremental search previews first match and restores on cancel",
    run = function()
      reset_case({ "alpha beta alpha gamma alpha" }, 1, 17)
      local original_cursor = vim.api.nvim_win_get_cursor(0)
      local preview_range = nil
      local group = vim.api.nvim_create_augroup("axelcool1234-test-search-preview", { clear = true })

      vim.api.nvim_create_autocmd("CmdlineChanged", {
        group = group,
        callback = function()
          if vim.fn.getcmdtype() == "/" and vim.fn.getcmdline() == "alpha" then
            preview_range = primary_selection_range()
          end
        end,
      })

      helix.search_regex()
      feed_deferred("alpha<Esc>", 20, 300)
      vim.api.nvim_del_augroup_by_id(group)

      assert_equal(
        preview_range,
        { start_row = 1, start_col = 24, end_row = 1, end_col = 28 },
        "typing /alpha should preview the next forward match before confirming"
      )

      assert_equal(vim.api.nvim_win_get_cursor(0), original_cursor, "cancelling an incremental search should restore the original cursor")
      assert_equal(primary_selection_range(), nil, "cancelling an incremental search should clear the temporary preview")
    end,
  },
  {
    name = "backward search starts backward but n and N keep fixed directions",
    run = function()
      reset_case({ "alpha beta alpha gamma alpha" }, 1, 17)

      helix.search_regex_backward()
      feed_deferred("alpha<CR>", 20, 300)

      assert_equal(
        primary_selection_range(),
        { start_row = 1, start_col = 12, end_row = 1, end_col = 16 },
        "? should first select the previous match"
      )

      helix.search_next("forward")
      assert_equal(
        primary_selection_range(),
        { start_row = 1, start_col = 24, end_row = 1, end_col = 28 },
        "n should still move forward after a ? search"
      )

      helix.search_next("backward")
      assert_equal(
        primary_selection_range(),
        { start_row = 1, start_col = 12, end_row = 1, end_col = 16 },
        "N should still move backward after a ? search"
      )
    end,
  },
  {
    name = "select regex writes to slash register and drives n",
    run = function()
      reset_case({ "alpha beta alpha gamma alpha" }, 1, 0)
      helix.select_regex_matches("alpha")

      assert_equal(
        all_cursor_positions(),
        { { 1, 5 }, { 1, 16 }, { 1, 28 } },
        "select regex without an existing preview should search the whole buffer"
      )

      local slash_entry = which_key_entry("/")
      assert(slash_entry ~= nil, "slash register should be listed in which-key registers")
      assert(slash_entry.desc:find("alpha", 1, true), "slash register preview should contain the last select regex pattern")
      assert(not slash_entry.desc:find("\\v", 1, true), "slash register preview should store the raw pattern, not the compiled Vim regex")

      helix.search_next("forward")
      assert_equal(
        primary_selection_range(),
        { start_row = 1, start_col = 12, end_row = 1, end_col = 16 },
        "n should continue from the regex selected by s via the slash register"
      )
    end,
  },
  {
    name = "explicit search register becomes active for n",
    run = function()
      reset_case({ "alpha beta alpha gamma alpha" }, 1, 0)
      helix.select_register("a")
      helix.select_regex_matches("alpha")

      local user_entry = which_key_entry("a")
      assert(user_entry ~= nil, "explicit search register should be listed after writing a search pattern")
      assert(user_entry.desc:find("alpha", 1, true), "explicit search register preview should contain the search pattern")
      assert(not user_entry.desc:find("\\v", 1, true), "explicit search register preview should store the raw pattern")

      helix.search_next("forward")
      assert_equal(
        primary_selection_range(),
        { start_row = 1, start_col = 12, end_row = 1, end_col = 16 },
        "n should use the last active search register, not only slash"
      )
    end,
  },
  {
    name = "star searches selections with word boundaries and drives n",
    run = function()
      reset_case({ "alpha beta alpha" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("alpha|beta")
      local seen = capture_echo(function()
        helix.search_selection_detect_word_boundaries()
      end)

      local slash_entry = which_key_entry("/")
      assert(slash_entry ~= nil, "slash register should exist after star search")
      assert(slash_entry.desc:find("<alpha>", 1, true), "star should add word boundaries around alpha")
      assert(slash_entry.desc:find("<beta>", 1, true), "star should add word boundaries around beta")
      assert_equal(seen[#seen], "register '/' set to '<alpha>|<beta>'", "star should echo which search register was updated")

      helix.search_next("forward")
      assert_equal(
        primary_selection_range(),
        { start_row = 1, start_col = 7, end_row = 1, end_col = 10 },
        "n after star should jump to the next whole-word match from the ORed selections"
      )
    end,
  },
  {
    name = "alt-star searches selections without word boundaries",
    run = function()
      reset_case({ "alphabeta" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("alpha|beta")
      helix.select_register("a")
      local seen = capture_echo(function()
        helix.search_selection()
      end)

      local slash_entry = which_key_entry("/")
      local user_entry = which_key_entry("a")
      assert(user_entry ~= nil, "explicit register should exist after alt-star search")
      assert(not user_entry.desc:find("<alpha>", 1, true), "alt-star should not add word boundaries around alpha")
      assert(not user_entry.desc:find("<beta>", 1, true), "alt-star should not add word boundaries around beta")
      assert_equal(seen[#seen], "register 'a' set to 'alpha|beta'", "alt-star should echo the explicitly selected search register")
    end,
  },
  {
    name = "gh goes to line start while gs goes to first non-blank",
    run = function()
      reset_case({ "   abc" }, 1, 5)
      helix.goto_line_start()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "gh should go to column 1")

      reset_case({ "   abc" }, 1, 5)
      helix.goto_first_nonblank()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 3 }, "gs should go to the first non-blank")
    end,
  },
  {
    name = "gl goes to line end",
    run = function()
      reset_case({ "abc   " }, 1, 0)
      helix.goto_line_end()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 5 }, "gl should go to the line end cell")
    end,
  },
  {
    name = "l and h traverse newline cells between lines",
    run = function()
      reset_case({ "abc", "def" }, 1, 3)
      helix.normal_motion("l")()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 0 }, "l from a newline cell should move to the next line start")

      helix.normal_motion("h")()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 3 }, "h from a line start should move back to the previous line newline cell")
    end,
  },
  {
    name = "b from end-of-line cell stays on the current line word",
    run = function()
      reset_case({ "abc", "def ghi" }, 2, 7)
      helix.apply_word_motion("prev_word_start")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 4 }, "b from the line-end cell should move to the previous word on the same line")
    end,
  },
  {
    name = "repeat last motion replays find-char motion",
    run = function()
      reset_case({ "abcaefca" }, 1, 0)
      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "c"
      end

      local ok, err = pcall(function()
        helix.find_char_motion("f")()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 2 }, "f should jump to the next matching character")
      helix.repeat_last_motion()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 6 }, "alt-dot should repeat the last find-char motion")
    end,
  },
  {
    name = "repeat last motion preserves select mode for find-char motion",
    run = function()
      reset_case({ "abcaefca" }, 1, 0)
      helix.toggle_select_mode()
      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "c"
      end

      local ok, err = pcall(function()
        helix.find_char_motion("f")()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "abc" }, "f in select mode should extend the selection to the first matching character")
      helix.repeat_last_motion()
      assert_equal(selection_texts(), { "abcaefc" }, "alt-dot should repeat find-char while preserving select mode extension semantics")
      assert_equal(vim.g.helix_mode_label, "SELECT", "alt-dot should keep select mode active when repeating a select-mode find-char motion")
    end,
  },
  {
    name = "reverse repeat last motion replays find-char in the opposite direction",
    run = function()
      reset_case({ "acbcdeca" }, 1, 1)
      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "c"
      end

      local ok, err = pcall(function()
        helix.find_char_motion("f")()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 3 }, "f should jump to the next matching character")
      helix.repeat_last_motion_reverse()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 1 }, "alt-shift-dot should replay the inverse find-char motion")
    end,
  },
  {
    name = "repeat last motion replays textobject selection with the captured object key",
    run = function()
      reset_case({ "alpha beta gamma" }, 1, 0)
      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "w"
      end

      local ok, err = pcall(function()
        helix.select_around_pair()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "alpha " }, "maw should select the first word around the cursor")
      helix.repeat_last_motion()
      assert_equal(selection_texts(), { "beta " }, "alt-dot should repeat maw with the remembered textobject key")
    end,
  },
  {
    name = "reverse repeat last motion falls back to forward replay for m-family motions",
    run = function()
      reset_case({ "alpha beta gamma" }, 1, 0)
      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "w"
      end

      local ok, err = pcall(function()
        helix.select_around_pair()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "alpha " }, "maw should select the first word around the cursor")
      helix.repeat_last_motion_reverse()
      assert_equal(selection_texts(), { "beta " }, "alt-shift-dot should behave like alt-dot for m-family repeats")
    end,
  },
  {
    name = "flash jump moves the primary cursor to the chosen visible word start",
    run = function()
      reset_case({ "alpha beta gamma" }, 1, 0)
      local original_getcharstr = vim.fn.getcharstr
      local inputs = { "b", "a" }
      vim.fn.getcharstr = function()
        local next_input = inputs[1]
        table.remove(inputs, 1)
        return next_input
      end

      local ok, err = pcall(function()
        helix.flash_jump()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 6 }, "z should jump to the narrowed labeled visible word start")
      assert_equal(selection_texts(), {}, "z in normal mode should leave no preview selection behind")
    end,
  },
  {
    name = "flash jump can switch to a visible match in another window",
    run = function()
      vim.cmd("only")
      reset_case({ "alpha" }, 1, 0)
      local left_win = vim.api.nvim_get_current_win()
      vim.cmd("vnew")
      local right_win = vim.api.nvim_get_current_win()
      vim.bo.filetype = "text"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "beta" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.api.nvim_set_current_win(left_win)

      local original_getcharstr = vim.fn.getcharstr
      local inputs = { "b", "a" }
      vim.fn.getcharstr = function()
        local next_input = inputs[1]
        table.remove(inputs, 1)
        return next_input
      end

      local ok, err = pcall(function()
        helix.flash_jump()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(vim.api.nvim_get_current_win(), right_win, "z should switch to the target window when the chosen match is visible there")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "z should place the cursor on the chosen match in the other window")
      vim.cmd("only")
    end,
  },
  {
    name = "flash jump collapses to primary and extends it in select mode",
    run = function()
      reset_case({ "alpha beta", "gamma" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("alpha|gamma")
      helix.toggle_select_mode()

      local original_getcharstr = vim.fn.getcharstr
      local inputs = { "b", "a" }
      vim.fn.getcharstr = function()
        local next_input = inputs[1]
        table.remove(inputs, 1)
        return next_input
      end

      local ok, err = pcall(function()
        helix.flash_jump()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "alpha b" }, "z in select mode should collapse to primary and extend it to the chosen target")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 6 }, "z in select mode should leave the primary cursor on the chosen target")
      assert_equal(vim.g.helix_mode_label, "SELECT", "z in select mode should stay in select mode")
    end,
  },
  {
    name = "flash jump reserves continuation characters before using them as labels",
    run = function()
      reset_case({ "noctalia cheatsheet chrono" }, 1, 0)
      local original_getcharstr = vim.fn.getcharstr
      local inputs = { "c", "h", nil }
      vim.fn.getcharstr = function()
        local next_input = inputs[1]
        table.remove(inputs, 1)
        return next_input
      end

      local ok, err = pcall(function()
        helix.flash_jump()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "typing z then c then h should keep narrowing instead of treating h as an immediate jump label")
    end,
  },
  {
    name = "cancelled flash jump restores the original multi-selection state",
    run = function()
      reset_case({ "alpha beta", "gamma" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("alpha|gamma")

      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return nil
      end

      local ok, err = pcall(function()
        helix.flash_jump()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "alpha", "gamma" }, "cancelling z should restore the original selections")
      assert_equal(all_cursor_positions(), { { 1, 5 }, { 2, 5 } }, "cancelling z should restore the original primary and secondary cursors")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "cancelling z from normal mode should restore normal mode")
    end,
  },
  {
    name = "flash treesitter selects the current syntax node",
    run = function()
      reset_case({ "return foo(bar)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")

      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "a"
      end

      local ok, err = pcall(function()
        helix.flash_treesitter()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "bar" }, "Z should select the innermost treesitter node under the cursor")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "Z in normal mode should keep normal mode")
    end,
  },
  {
    name = "flash treesitter stays in select mode after picking a node",
    run = function()
      reset_case({ "return foo(bar)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")
      helix.toggle_select_mode()

      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "a"
      end

      local ok, err = pcall(function()
        helix.flash_treesitter()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "bar" }, "Z in select mode should replace the primary selection with the chosen syntax node")
      assert_equal(vim.g.helix_mode_label, "SELECT", "Z in select mode should stay in select mode")
    end,
  },
  {
    name = "flash treesitter renders overlay labels on the adjacent boundary characters",
    run = function()
      reset_case({ "return foo(bar)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")

      local line = current_lines()[1]
      local start_col0 = assert(line:find("bar", 1, true), "expected test fixture to contain bar") - 1
      local before_col0 = start_col0 - 1
      local after_col0 = start_col0 + #"bar"
      local original_set_extmark = vim.api.nvim_buf_set_extmark
      local seen = {}

      vim.api.nvim_buf_set_extmark = function(buffer, ns, row, col, opts)
        if opts and opts.virt_text and opts.virt_text[1] and opts.virt_text[1][1] == "a" and opts.virt_text[1][2] == "HelixFlashLabel" then
          seen[string.format("%d:%d:%s", row, col, opts.virt_text_pos or "overlay")] = true
        end
        return original_set_extmark(buffer, ns, row, col, opts)
      end

      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "a"
      end

      local ok, err = pcall(function()
        helix.flash_treesitter()
      end)
      vim.fn.getcharstr = original_getcharstr
      vim.api.nvim_buf_set_extmark = original_set_extmark
      if not ok then
        error(err)
      end

      assert_equal(seen[string.format("0:%d:overlay", before_col0)], true, "Z should render the first treesitter label over the character before the range")
      assert_equal(seen[string.format("0:%d:overlay", after_col0)], true, "Z should also render the first treesitter label over the character after the range")
    end,
  },
  {
    name = "flash treesitter coalesces shared end-boundary labels into one extmark",
    run = function()
      reset_case({ "return foo(bar)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")

      local line = current_lines()[1]
      local after_col0 = assert(line:find("bar", 1, true), "expected test fixture to contain bar") + #"bar"
      local original_set_extmark = vim.api.nvim_buf_set_extmark
      local max_label_chunk_count = 0

      vim.api.nvim_buf_set_extmark = function(buffer, ns, row, col, opts)
        if row == 0 and col == after_col0 and opts and opts.virt_text and (opts.virt_text_pos or "overlay") == "overlay" then
          local all_labels = true
          for _, chunk in ipairs(opts.virt_text) do
            if chunk[2] ~= "HelixFlashLabel" then
              all_labels = false
              break
            end
          end
          if all_labels then
            max_label_chunk_count = math.max(max_label_chunk_count, #opts.virt_text)
          end
        end
        return original_set_extmark(buffer, ns, row, col, opts)
      end

      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "a"
      end

      local ok, err = pcall(function()
        helix.flash_treesitter()
      end)
      vim.fn.getcharstr = original_getcharstr
      vim.api.nvim_buf_set_extmark = original_set_extmark
      if not ok then
        error(err)
      end

      assert_equal(max_label_chunk_count > 1, true, "Z should coalesce labels that share the same treesitter end boundary into one extmark")
    end,
  },
  {
    name = "flash treesitter does not render the dim backdrop",
    run = function()
      reset_case({ "return foo(bar)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")

      local original_set_extmark = vim.api.nvim_buf_set_extmark
      local backdrop_count = 0

      vim.api.nvim_buf_set_extmark = function(buffer, ns, row, col, opts)
        if opts and opts.hl_group == "HelixFlashBackdrop" then
          backdrop_count = backdrop_count + 1
        end
        return original_set_extmark(buffer, ns, row, col, opts)
      end

      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "a"
      end

      local ok, err = pcall(function()
        helix.flash_treesitter()
      end)
      vim.fn.getcharstr = original_getcharstr
      vim.api.nvim_buf_set_extmark = original_set_extmark
      if not ok then
        error(err)
      end

      assert_equal(backdrop_count, 0, "Z should not dim the whole window like the word-flash picker")
    end,
  },
  {
    name = "flash treesitter renders a current range highlight",
    run = function()
      reset_case({ "return foo(bar)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")

      local original_set_extmark = vim.api.nvim_buf_set_extmark
      local highlighted_range_count = 0

      vim.api.nvim_buf_set_extmark = function(buffer, ns, row, col, opts)
        if opts and opts.hl_group == "HelixFlashCurrent" then
          highlighted_range_count = highlighted_range_count + 1
        end
        return original_set_extmark(buffer, ns, row, col, opts)
      end

      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "a"
      end

      local ok, err = pcall(function()
        helix.flash_treesitter()
      end)
      vim.fn.getcharstr = original_getcharstr
      vim.api.nvim_buf_set_extmark = original_set_extmark
      if not ok then
        error(err)
      end

      assert_equal(highlighted_range_count > 0, true, "Z should render a lightweight highlight for the current treesitter target while the picker is open")
    end,
  },
  {
    name = "flash treesitter renders a cursor-style extmark on the current target end",
    run = function()
      reset_case({ "return foo(bar)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")

      local line = current_lines()[1]
      local end_col0 = assert(line:find("bar", 1, true), "expected test fixture to contain bar") + #"bar" - 2
      local original_set_extmark = vim.api.nvim_buf_set_extmark
      local seen = {}

      vim.api.nvim_buf_set_extmark = function(buffer, ns, row, col, opts)
        if opts and opts.hl_group == "HelixFlashCursor" then
          seen[string.format("%d:%d", row, col)] = true
        end
        return original_set_extmark(buffer, ns, row, col, opts)
      end

      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "a"
      end

      local ok, err = pcall(function()
        helix.flash_treesitter()
      end)
      vim.fn.getcharstr = original_getcharstr
      vim.api.nvim_buf_set_extmark = original_set_extmark
      if not ok then
        error(err)
      end

      assert_equal(seen[string.format("0:%d", end_col0)], true, "Z should render a cursor-style highlight on the current target end boundary")
    end,
  },
  {
    name = "flash treesitter advances to the next enclosing node when the current selection already matches one",
    run = function()
      reset_case({ "return foo(bar)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")

      local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
      local original_getcharstr = vim.fn.getcharstr
      local inputs = { cr, cr }
      vim.fn.getcharstr = function()
        local next_input = inputs[1]
        table.remove(inputs, 1)
        return next_input
      end

      local ok, err = pcall(function()
        helix.flash_treesitter()
        helix.flash_treesitter()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "(bar)" }, "pressing Z then Enter twice should advance from the current node to the next enclosing syntax node")
    end,
  },
  {
    name = "flash treesitter wraps n and p navigation",
    run = function()
      reset_case({ "return foo(bar)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")

      local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
      local original_getcharstr = vim.fn.getcharstr
      local inputs = { "p", cr }
      vim.fn.getcharstr = function()
        local next_input = inputs[1]
        table.remove(inputs, 1)
        return next_input
      end

      local ok, err = pcall(function()
        helix.flash_treesitter()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "return foo(bar)" }, "p from the first Z candidate should wrap to the outermost node")

      reset_case({ "return foo(bar)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")

      local inputs2 = { "p", "n", cr }
      vim.fn.getcharstr = function()
        local next_input = inputs2[1]
        table.remove(inputs2, 1)
        return next_input
      end

      ok, err = pcall(function()
        helix.flash_treesitter()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "bar" }, "n should wrap back to the innermost Z candidate after p wrapped to the outermost one")
    end,
  },
  {
    name = "goto function stays on the selected function when moving backward and advances to the next function when moving forward",
    run = function()
      reset_case({ "", "ChangeResult Executable::setToLive() {", "  if (live)", "    return ChangeResult::NoChange;", "  live = true;", "  return ChangeResult::Change;", "}", "", "ChangeResult Executable::other() {", "  return ChangeResult::Change;", "}" }, 1, 0)
      vim.bo.filetype = "cpp"
      pcall(vim.treesitter.start, 0, "cpp")

      helix.goto_textobject("function", "forward")
      assert_equal(selection_texts(), { "ChangeResult Executable::setToLive() {\n  if (live)\n    return ChangeResult::NoChange;\n  live = true;\n  return ChangeResult::Change;\n}" }, "]f should select the whole function definition")

      helix.goto_textobject("function", "backward")
      assert_equal(selection_texts(), { "ChangeResult Executable::setToLive() {\n  if (live)\n    return ChangeResult::NoChange;\n  live = true;\n  return ChangeResult::Change;\n}" }, "[f from an exact function selection should not descend into function.inner captures")

      helix.goto_textobject("function", "forward")
      assert_equal(selection_texts(), { "ChangeResult Executable::other() {\n  return ChangeResult::Change;\n}" }, "]f from an exact function selection should advance to the next function definition")
    end,
  },
  {
    name = "reverse repeat last motion replays goto-textobject backward",
    run = function()
      reset_case({ "", "ChangeResult Executable::setToLive() {", "  if (live)", "    return ChangeResult::NoChange;", "  live = true;", "  return ChangeResult::Change;", "}", "", "ChangeResult Executable::other() {", "  return ChangeResult::Change;", "}" }, 1, 0)
      vim.bo.filetype = "cpp"
      pcall(vim.treesitter.start, 0, "cpp")

      helix.goto_textobject("function", "forward")
      helix.repeat_last_motion()
      assert_equal(selection_texts(), { "ChangeResult Executable::other() {\n  return ChangeResult::Change;\n}" }, "alt-dot after ]f should advance to the next function")

      helix.repeat_last_motion_reverse()
      assert_equal(selection_texts(), { "ChangeResult Executable::setToLive() {\n  if (live)\n    return ChangeResult::NoChange;\n  live = true;\n  return ChangeResult::Change;\n}" }, "alt-shift-dot after ]f should replay the matching [f motion")
    end,
  },
  {
    name = "goto function from inside a function body skips function.inner captures and moves to the next function",
    run = function()
      reset_case({ "ChangeResult Executable::setToLive() {", "  if (live)", "    return ChangeResult::NoChange;", "  live = true;", "  return ChangeResult::Change;", "}", "", "void Executable::print(raw_ostream &os) const {", "  os << (live ? \"live\" : \"dead\");", "}" }, 3, 4)
      vim.bo.filetype = "cpp"
      pcall(vim.treesitter.start, 0, "cpp")

      helix.goto_textobject("function", "forward")
      assert_equal(selection_texts(), { "void Executable::print(raw_ostream &os) const {\n  os << (live ? \"live\" : \"dead\");\n}" }, "]f from inside a function body should jump to the next function, not another statement in the current body")
    end,
  },
  {
    name = "goto function in cpp progresses from a function body to a lambda and then to the next function",
    run = function()
      reset_case({ "ChangeResult Executable::setToLive() {", "  if (live)", "    return ChangeResult::NoChange;", "  live = true;", "  return ChangeResult::Change;", "}", "", "auto f = []() { return 1; };", "", "void Executable::print(raw_ostream &os) const {", "  os << (live ? \"live\" : \"dead\");", "}" }, 3, 4)
      vim.bo.filetype = "cpp"
      pcall(vim.treesitter.start, 0, "cpp")

      helix.goto_textobject("function", "forward")
      assert_equal(selection_texts(), { "[]() { return 1; }" }, "]f should still see the lambda as the next function-like object")

      helix.goto_textobject("function", "forward")
      assert_equal(selection_texts(), { "void Executable::print(raw_ostream &os) const {\n  os << (live ? \"live\" : \"dead\");\n}" }, "repeating ]f after the lambda should continue to the next function definition")
    end,
  },
  {
    name = "maz and miz apply treesitter node selection to multiple cursors",
    run = function()
      reset_case({ "return foo(bar)", "return baz(qux)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")
      helix.copy_selection_on_adjacent_line(1)

      local original_getcharstr = vim.fn.getcharstr
      local inputs = { "z", "z", "z" }
      vim.fn.getcharstr = function()
        local next_input = inputs[1]
        table.remove(inputs, 1)
        return next_input
      end

      local ok, err = pcall(function()
        helix.select_around_pair()
        helix.select_around_pair()
        helix.select_inside_pair()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "bar", "qux" }, "maz and miz should apply the treesitter node transform to every active cursor")
      assert_equal(all_cursor_positions(), { { 1, 14 }, { 2, 14 } }, "miz should preserve one selection per active cursor")
    end,
  },
  {
    name = "cpp parameter motions use helix-style around captures with commas",
    run = function()
      reset_case({ "void DeadCodeAnalysis::markEdgeLive(Block *from, Block *to) {", "  LDBG() << \"Marking edge live from block \" << from << \" to block \" << to;", "}" }, 1, 0)
      vim.bo.filetype = "cpp"
      pcall(vim.treesitter.start, 0, "cpp")

      helix.goto_textobject("parameter", "forward")
      assert_equal(selection_texts(), { "Block *from," }, "]a should select the first parameter including its trailing comma")

      helix.goto_textobject("parameter", "forward")
      assert_equal(selection_texts(), { "Block *to" }, "repeating ]a should move to the next parameter instead of stopping on the comma")

      helix.goto_textobject("parameter", "backward")
      assert_equal(selection_texts(), { "Block *from," }, "[a should move back to the previous parameter around capture")
    end,
  },
  {
    name = "maa in cpp includes the trailing comma in around parameter selection",
    run = function()
      reset_case({ "void DeadCodeAnalysis::markEdgeLive(Block *from, Block *to) {", "}" }, 1, 42)
      vim.bo.filetype = "cpp"
      pcall(vim.treesitter.start, 0, "cpp")

      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "a"
      end

      local ok, err = pcall(function()
        helix.select_around_pair()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "Block *from," }, "maa on a cpp parameter should include the trailing comma like Helix")
    end,
  },
  {
    name = "treesitter sibling goto moves multiple cursors together",
    run = function()
      reset_case({ "return foo, bar, baz", "return one, two, three" }, 1, 8)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")
      helix.copy_selection_on_adjacent_line(1)

      helix.goto_treesitter_sibling("forward")
      assert_equal(selection_texts(), { "bar", "two" }, "]z should move every active cursor to its next treesitter sibling")

      helix.goto_treesitter_sibling("backward")
      assert_equal(selection_texts(), { "foo", "one" }, "[z should move every active cursor to its previous treesitter sibling")
    end,
  },
  {
    name = "treesitter sibling edge goto moves multiple cursors together",
    run = function()
      reset_case({ "return foo, bar, baz", "return one, two, three" }, 1, 8)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")
      helix.copy_selection_on_adjacent_line(1)

      helix.goto_treesitter_sibling("forward")
      helix.goto_treesitter_sibling_edge("last")
      assert_equal(selection_texts(), { "baz", "three" }, "]Z should move every active cursor to the last treesitter sibling")

      helix.goto_treesitter_sibling_edge("first")
      assert_equal(selection_texts(), { "foo", "one" }, "[Z should move every active cursor to the first treesitter sibling")
    end,
  },
  {
    name = "treesitter child goto moves multiple cursors together",
    run = function()
      reset_case({ "return foo(bar, baz)", "return qux(one, two)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")
      helix.copy_selection_on_adjacent_line(1)

      local original_getcharstr = vim.fn.getcharstr
      local inputs = { "z", "z", "z" }
      vim.fn.getcharstr = function()
        local next_input = inputs[1]
        table.remove(inputs, 1)
        return next_input
      end

      local ok, err = pcall(function()
        helix.select_around_pair()
        helix.select_around_pair()
        helix.goto_treesitter_child("last")
      end)
      if not ok then
        vim.fn.getcharstr = original_getcharstr
        error(err)
      end

      assert_equal(selection_texts(), { "baz", "two" }, "gZ should move every active selection to the last named child")

      ok, err = pcall(function()
        helix.select_around_pair()
        helix.goto_treesitter_child("first")
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "bar", "one" }, "gz should move every active selection to the first named child after gZ moved to the last child")
      assert_equal(all_cursor_positions(), { { 1, 14 }, { 2, 14 } }, "gz and gZ should preserve one AST selection per active cursor")
    end,
  },
  {
    name = "maZ selects the largest useful ancestor instead of the whole file root",
    run = function()
      reset_case({ "return foo(bar)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")

      local original_getcharstr = vim.fn.getcharstr
      vim.fn.getcharstr = function()
        return "Z"
      end

      local ok, err = pcall(function()
        helix.select_around_pair()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "return foo(bar)" }, "maZ should select the largest useful ancestor below the file root")
    end,
  },
  {
    name = "maZ and miZ apply coarse treesitter selection to multiple cursors",
    run = function()
      reset_case({ "return foo(bar)", "return baz(qux)" }, 1, 11)
      vim.bo.filetype = "lua"
      pcall(vim.treesitter.start, 0, "lua")
      helix.copy_selection_on_adjacent_line(1)

      local original_getcharstr = vim.fn.getcharstr
      local inputs = { "Z", "Z" }
      vim.fn.getcharstr = function()
        local next_input = inputs[1]
        table.remove(inputs, 1)
        return next_input
      end

      local ok, err = pcall(function()
        helix.select_around_pair()
        helix.select_inside_pair()
      end)
      vim.fn.getcharstr = original_getcharstr
      if not ok then
        error(err)
      end

      assert_equal(selection_texts(), { "return foo(bar)", "return baz(qux)" }, "maZ and miZ should apply the coarse treesitter selection to every active cursor")
      assert_equal(all_cursor_positions(), { { 1, 15 }, { 2, 15 } }, "coarse AST selection should preserve one selection per active cursor")
    end,
  },
  {
    name = "trim selection removes surrounding spaces and blank lines",
    run = function()
      reset_case({ "", "  alpha  ", "" }, 1, 0)
      helix.select_whole_buffer()
      helix.trim_current_preview_selection()
      assert_equal(selection_texts(), { "alpha" }, "_ should trim whitespace and newline-only edges from the selection")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 6 }, "_ should leave the cursor on the trimmed selection end")
    end,
  },
  {
    name = "select whole buffer leaves cursor on eof cell of last line",
    run = function()
      reset_case({ "abc", "def" }, 1, 0)
      helix.select_whole_buffer()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 3 }, "% should leave the cursor on the eof cell of the last line")
      assert_equal(selection_texts(), { "abc\ndef" }, "% should still select the whole buffer")
    end,
  },
  {
    name = "counted gg goes to counted line start and merges cursors",
    run = function()
      reset_case({ "one", "two", "three", "four" }, 3, 1)
      helix.copy_selection_on_adjacent_line(1)
      feed("2gg")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 0 }, "2gg should land on the start of line 2")
      assert_equal(all_cursor_positions(), { { 2, 1 } }, "2gg should merge multiple cursors onto the same line start")
    end,
  },
  {
    name = "control u can move cursor to first line",
    run = function()
      local lines = {}
      for index = 1, 40 do
        lines[index] = "line " .. index
      end
      reset_case(lines, 5, 0)
      helix.scroll_half_page(-1)
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "control-u should allow the cursor to reach the first line")
    end,
  },
  {
    name = "paragraph motions leave selections",
    run = function()
      reset_case({ "", "", "alpha", "beta", "", "gamma", "delta", "", "zeta" }, 1, 0)
      helix.goto_paragraph("forward")
      assert_equal(selection_texts(), { "\n\n" }, "]p should treat leading blank lines as one block")

      helix.goto_paragraph("forward")
      assert_equal(selection_texts(), { "alpha\nbeta\n\n" }, "next ]p should select the next paragraph and its separator")

      helix.goto_paragraph("forward")
      assert_equal(selection_texts(), { "gamma\ndelta\n\n" }, "further ]p should continue paragraph by paragraph")

      reset_case({ "", "", "alpha", "beta", "", "gamma", "delta", "", "zeta" }, 6, 0)
      helix.goto_paragraph("backward")
      assert_equal(selection_texts(), { "alpha\nbeta\n\n" }, "[p should select the previous paragraph and its separator")

      reset_case({ "", "", "alpha", "beta", "", "gamma", "delta", "", "zeta" }, 5, 0)
      helix.goto_paragraph("backward")
      assert_equal(selection_texts(), { "alpha\nbeta\n\n" }, "[p from a separator should select the previous paragraph and its separator")
    end,
  },
  {
    name = "paragraph motions extend in select mode",
    run = function()
      reset_case({ "one", "", "two", "", "three", "" }, 3, 0)
      helix.goto_paragraph("forward")
      helix.toggle_select_mode()
      helix.goto_paragraph("forward")
      assert_equal(selection_texts(), { "two\n\nthree\n" }, "]p in select mode should extend through the next paragraph")
    end,
  },
  {
    name = "paragraph motion from blank line includes final paragraph at eof",
    run = function()
      reset_case({ "intro", "", "Notes:", "- one", "- two" }, 2, 0)
      leave_single_preview_active()
      helix.goto_paragraph("forward")
      assert_equal(selection_texts(), { "Notes:\n- one\n- two" }, "]p from a separator before the final paragraph should include the paragraph through eof")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 5, 5 }, "]p should leave the cursor on the eof cell of the final paragraph")
    end,
  },
  {
    name = "repeat last motion replays paragraph motion",
    run = function()
      reset_case({ "one", "", "two", "", "three", "" }, 1, 0)
      helix.goto_paragraph("forward")
      assert_equal(selection_texts(), { "one\n\n" }, "]p should first select the current paragraph and separator")

      helix.repeat_last_motion()
      assert_equal(selection_texts(), { "two\n\n" }, "alt-dot should repeat the last paragraph motion")
    end,
  },
  {
    name = "repeat last motion replays diagnostic goto",
    run = function()
      reset_case({ "alpha", "oops", "beta", "warn" }, 1, 0)
      local ns = vim.api.nvim_create_namespace("motion-test-diagnostic-repeat")
      vim.diagnostic.set(ns, 0, {
        { lnum = 1, col = 0, end_lnum = 1, end_col = 4, message = "oops", severity = vim.diagnostic.severity.ERROR },
        { lnum = 3, col = 0, end_lnum = 3, end_col = 4, message = "warn", severity = vim.diagnostic.severity.WARN },
      })

      helix.goto_diagnostic("forward")
      assert_equal(selection_texts(), { "oops" }, "]d should select the next diagnostic range")

      helix.repeat_last_motion()
      assert_equal(selection_texts(), { "warn" }, "alt-dot should repeat the last diagnostic motion")
    end,
  },
  {
    name = "ensure forward selection direction restores forward cursor",
    run = function()
      reset_case({ "abc" }, 1, 0)
      helix.select_whole_buffer()
      helix.flip_selection_direction()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "flipped selection should place the cursor at the start")
      helix.ensure_forward_selection_direction()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 3 }, "ensure forward should place the cursor back at the end")
    end,
  },
  {
    name = "ampersand aligns single selection column across rows",
    run = function()
      reset_case({ "a = 1", "bbbb = 2" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("[=]")
      feed("&")
      assert_equal(current_lines(), { "a    = 1", "bbbb = 2" }, "& should pad earlier rows so the selected columns align")
      assert_equal(all_cursor_positions(), { { 1, 6 }, { 2, 6 } }, "& should keep both selections on the aligned column")
    end,
  },
  {
    name = "ampersand aligns repeated selection columns independently",
    run = function()
      reset_case({ "a=1,bb=2", "long=3,c=4" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("[=]")
      feed("&")
      assert_equal(current_lines(), { "a   =1,bb=2", "long=3,c =4" }, "& should align each selection column group separately")
      assert_equal(
        all_cursor_positions(),
        { { 1, 5 }, { 1, 10 }, { 2, 5 }, { 2, 10 } },
        "& should preserve the grouped selection columns after padding"
      )
    end,
  },
  {
    name = "change motions extend in select mode",
    run = function()
      local cache = require("gitsigns.cache").cache
      reset_case({ "one", "two", "three", "four" }, 1, 0)
      local first_bufnr = vim.api.nvim_get_current_buf()
      cache[first_bufnr] = {
        get_hunks = function()
          return {
            {
              added = { start = 2, count = 2 },
              vend = 3,
            },
          }
        end,
      }
      helix.toggle_select_mode()
      helix.goto_change("next")
      assert_equal(selection_texts(), { "one\ntwo\nthree\n" }, "]g in select mode should extend from the anchor through the hunk")
      cache[first_bufnr] = nil

      reset_case({ "one", "two", "three", "four" }, 4, 0)
      local second_bufnr = vim.api.nvim_get_current_buf()
      cache[second_bufnr] = {
        get_hunks = function()
          return {
            {
              added = { start = 2, count = 2 },
              vend = 3,
            },
          }
        end,
      }
      helix.toggle_select_mode()
      helix.goto_change("prev")
      assert_equal(selection_texts(), { "two\nthree\nf" }, "[g in select mode should extend to the start of the previous hunk")
      cache[second_bufnr] = nil
    end,
  },
  {
    name = "delete and change without yanking preserve unnamed register",
    run = function()
      reset_case({ "saved" }, 1, 0)
      helix.select_whole_buffer()
      helix.yank_selection('"')

      reset_case({ "abc" }, 1, 0)
      helix.select_whole_buffer()
      helix.delete("_")
      assert_equal(current_lines(), { "" }, "alt-d behavior should delete the selection")

      reset_case({ "x" }, 1, 0)
      helix.replace_selection_with_yank('"')
      assert_equal(current_lines(), { "saved" }, "alt-d behavior should not clobber the unnamed register")

      reset_case({ "saved2" }, 1, 0)
      helix.select_whole_buffer()
      helix.yank_selection('"')

      reset_case({ "abc" }, 1, 0)
      helix.select_whole_buffer()
      helix.change_selection("_")
      assert_equal(current_lines(), { "" }, "alt-c behavior should delete the selection before insert")

      reset_case({ "x" }, 1, 0)
      helix.replace_selection_with_yank('"')
      assert_equal(current_lines(), { "saved2" }, "alt-c behavior should not clobber the unnamed register")
    end,
  },
  {
    name = "leader R clipboard replacement uses per-cursor values",
    run = function()
      reset_case({ "a b c" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("[abc]")
      helix.yank_selection("+")

      reset_case({ "x x x" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("x")
      helix.replace_selection_with_yank("+")

      assert_equal(current_lines(), { "a b c" }, "clipboard replacement should map one clipboard value per cursor")
    end,
  },
  {
    name = "leader Y yanks only primary selection to clipboard",
    run = function()
      reset_case({ "a b c" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("[abc]")
      helix.yank_primary_selection("+")

      reset_case({ "x x x" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("x")
      helix.replace_selection_with_yank("+")

      assert_equal(current_lines(), { "a a a" }, "leader Y should put only the primary selection in the clipboard register")
    end,
  },
  {
    name = "yank in select mode exits to normal mode",
    run = function()
      reset_case({ "aa aa" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("aa")
      helix.toggle_select_mode()

      local seen = capture_echo(function()
        helix.yank_selection('"')
      end)

      assert_equal(selection_texts(), { "aa", "aa" }, "y in select mode should keep the active selections")
      assert_equal(seen[#seen], 'yanked 2 selections to register "', "y in select mode should report the yank destination")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "y in select mode should leave select mode")
    end,
  },
  {
    name = "clipboard yank in select mode exits to normal mode",
    run = function()
      reset_case({ "aa aa" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("aa")
      helix.toggle_select_mode()

      local seen = capture_echo(function()
        helix.yank_selection("+")
      end)

      assert_equal(selection_texts(), { "aa", "aa" }, "clipboard yank in select mode should keep the active selections")
      assert_equal(seen[#seen], "yanked 2 selections to register +", "clipboard yank in select mode should report the yank destination")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "clipboard yank in select mode should leave select mode")
    end,
  },
  {
    name = "selected register appears in lualine state and clears",
    run = function()
      reset_case({ "abc" }, 1, 0)
      local register_component = require("lualine").get_config().sections.lualine_x[2]

      assert_equal(register_component.cond(), false, "lualine register indicator should be absent before selecting a register")
      helix.select_register("a")

      assert_equal(vim.g.helix_selected_register, "a", "register selection should set the shared lualine state")
      assert_equal(register_component.cond(), true, "lualine register indicator should activate when a register is selected")
      assert_equal(register_component[1](), "reg=a", "lualine should render the selected register indicator")

      helix.clear_selected_register()
      assert_equal(vim.g.helix_selected_register, nil, "clearing the selected register should clear the shared lualine state")
      assert_equal(register_component.cond(), false, "lualine register indicator should disappear after clearing")
    end,
  },
  {
    name = "default quote register popup item keeps the quote key",
    run = function()
      reset_case({ "abc" }, 1, 0)
      helix.yank_selection('"')

      local quote_entry = which_key_entry('"')
      assert(quote_entry ~= nil, "default quote register should be listed after a yank")

      local quote_item = which_key_item('"')
      assert(quote_item ~= nil, "default quote register should be exposed as a plugin popup item")
      assert_equal(quote_item.key, '"', "default quote register popup item should keep the quote key")
      assert_equal(quote_item.value, "a", "default quote register popup item should keep the plain preview contents")
      assert(type(quote_item.action) == "function", "default quote register popup item should keep a callable selection action")
    end,
  },
  {
    name = "special registers keep label-only picker descriptions",
    run = function()
      reset_case({ "abc" }, 1, 0)

      local index_entry = which_key_entry("#")
      assert(index_entry ~= nil, "selection-index register should always be listed")
      assert_equal(index_entry.desc, "<selection indices>", "special register descriptions should omit live contents")
    end,
  },
  {
    name = "symbol registers appear in the picker after writes",
    run = function()
      reset_case({ "abc" }, 1, 0)
      helix.yank_selection("$")

      local symbol_entry = which_key_entry("$")
      assert(symbol_entry ~= nil, "printable symbol registers should appear in the picker after storing text")
      assert_equal(symbol_entry.desc, "a", "symbol register picker entries should show the stored preview text")

      local symbol_item = which_key_item("$")
      assert(symbol_item ~= nil, "printable symbol registers should also appear in the popup item list")
      assert_equal(symbol_item.key, "$", "symbol register popup items should keep the original symbol key")
      assert_equal(symbol_item.value, "a", "symbol register popup items should keep the stored preview text")
    end,
  },
  {
    name = "special registers stay in a fixed tail order",
    run = function()
      reset_case({ "abc" }, 1, 0)
      helix.yank_selection('"')
      helix.yank_selection("$")

      assert(vim.tbl_contains(require("which-key.config").sort, "order"), "which-key sort should include order so plugin panels preserve explicit item ordering")

      local items = helix.which_key_register_items()
      local tail = {}
      for index = math.max(#items - 5, 1), #items do
        tail[#tail + 1] = items[index].key
      end

      assert_equal(tail, { "_", "#", ".", "%", "+", "*" }, "special registers should remain grouped at the end of the popup item list in the configured order")
    end,
  },
  {
    name = "colon register exposes the last executed command",
    run = function()
      reset_case({ "abc" }, 1, 0)
      local keys = vim.api.nvim_replace_termcodes(":set number<CR>", true, false, true)
      vim.api.nvim_feedkeys(keys, "xt", false)
      vim.wait(100)

      assert_equal(helix.read_register(":"), { "set number" }, "colon register should read the last interactive Ex command")

      local colon_entry = which_key_entry(":")
      assert(colon_entry ~= nil, "colon register should be listed in which-key registers")
      assert(colon_entry.desc:find("set number", 1, true), "colon register preview should show the last executed command")
    end,
  },
  {
    name = "colon register remains writable like a normal register",
    run = function()
      reset_case({ "abc" }, 1, 0)
      helix.yank_selection(":")

      assert_equal(helix.read_register(":"), { "a" }, "colon register should accept ordinary register writes")

      local colon_entry = which_key_entry(":")
      assert(colon_entry ~= nil, "colon register should still be listed after an explicit write")
      assert(colon_entry.desc:find("a", 1, true), "colon register preview should show explicitly written contents")
    end,
  },
  {
    name = "selected percent register escapes for lualine",
    run = function()
      reset_case({ "abc" }, 1, 0)
      local register_component = require("lualine").get_config().sections.lualine_x[2]

      local ok, err = pcall(helix.select_register, "%")
      assert_equal(ok, true, "selecting the percent register should not break lualine refresh: " .. tostring(err))
      assert_equal(vim.g.helix_selected_register, "%", "percent register selection should still preserve the raw register name")
      assert_equal(register_component.cond(), true, "percent register should still activate the lualine indicator")
      assert_equal(register_component[1](), "reg=%%", "lualine register indicator should escape percent for statusline rendering")
    end,
  },
  {
    name = "helix macro record and replay use custom registers",
    run = function()
      reset_case({ "one", "two", "three" }, 1, 0)
      local lualine_x = require("lualine").get_config().sections.lualine_x
      local recording_component = lualine_x[1]
      local register_component = lualine_x[2]

      assert_equal(recording_component.cond(), false, "recording indicator should be absent before macro recording starts")
      assert_equal(register_component.cond(), false, "selected register indicator should be absent before selecting a register")

      helix.select_register("a")
      assert_equal(register_component.cond(), true, "selected register indicator should activate when a register is selected")
      assert_equal(register_component[1](), "reg=a", "selected register indicator should show the chosen register before recording")

      helix.record_macro()
      assert_equal(vim.g.helix_macro_recording_register, "a", "macro recording should set shared lualine recording state")
      assert_equal(recording_component.cond(), true, "recording indicator should activate during macro recording")
      assert_equal(recording_component[1](), "[a]", "recording indicator should render the Helix target register")
      feed("j")
      local seen = capture_echo(function()
        helix.record_macro()
      end)

      assert_equal(seen[#seen], "Recorded to register [a]", "Q should store the recorded macro in the selected helix register")
      assert_equal(vim.g.helix_macro_recording_register, nil, "macro recording state should clear after recording stops")
      assert_equal(recording_component.cond(), false, "recording indicator should disappear after macro recording stops")
      local user_entry = which_key_entry("a")
      assert(user_entry ~= nil, "recorded macro register should appear in the register list")
      assert(user_entry.desc:find("j", 1, true), "recorded macro register preview should show the macro contents")
      assert(not user_entry.desc:find("Q", 1, true), "recorded macro preview should not include the stop-recording key")
      local at_entry = which_key_entry("@")
      assert(at_entry == nil, "at register should stay empty when recording into an explicitly selected register")

      reset_case({ "one", "two", "three" }, 1, 0)
      helix.select_register("a")
      helix.replay_macro()
      assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 0 }, "q should replay the macro from the selected helix register")
    end,
  },
  {
    name = "rotate selections changes primary selection in buffer order",
    run = function()
      reset_case({ "aa", "bb", "cc" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("aa|bb|cc")

      helix.rotate_selections("forward")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 1 }, ") should move the primary selection to the next selection in buffer order")
      assert_equal(selection_texts(), { "aa", "bb", "cc" }, ") should not change selection contents")

      helix.rotate_selections("backward")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 1 }, "( should move the primary selection back in buffer order")
      assert_equal(selection_texts(), { "aa", "bb", "cc" }, "( should still leave selection contents unchanged")
    end,
  },
  {
    name = "rotate selection contents reorders texts and primary together",
    run = function()
      reset_case({ "aa", "bb", "cc" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("aa|bb|cc")

      helix.rotate_selection_contents("forward")
      assert_equal(current_lines(), { "cc", "aa", "bb" }, "alt-) should rotate selected texts forward")
      assert_equal(selection_texts(), { "cc", "aa", "bb" }, "alt-) should keep selections on the rotated texts")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 1 }, "alt-) should move the primary selection with its original content")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "rotating selection contents should not enter select mode")

      helix.rotate_selection_contents("backward")
      assert_equal(current_lines(), { "aa", "bb", "cc" }, "alt-( should rotate selected texts backward")
      assert_equal(selection_texts(), { "aa", "bb", "cc" }, "alt-( should restore the original selected texts")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 1 }, "alt-( should restore the original primary selection")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "rotating selection contents backward should stay in normal mode")
    end,
  },
  {
    name = "toggle comments comments and uncomments selections while leaving select mode",
    run = function()
      reset_case({ "alpha", "beta" }, 1, 0)
      vim.bo.commentstring = "-- %s"
      helix.select_whole_buffer()
      helix.select_regex_matches("alpha|beta")
      helix.toggle_select_mode()

      helix.toggle_comments()
      assert_equal(current_lines(), { "-- alpha", "-- beta" }, "toggle comments should comment the selected lines")
      assert_equal(selection_texts(), { "alpha", "beta" }, "toggle comments should keep selections on the original text")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "toggle comments should leave select mode")

      helix.toggle_comments()
      assert_equal(current_lines(), { "alpha", "beta" }, "toggle comments should uncomment already commented lines")
      assert_equal(selection_texts(), { "alpha", "beta" }, "uncommenting should still preserve the selections")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "uncommenting should stay in normal mode")
    end,
  },
  {
    name = "toggle line comments comments and uncomments selections while leaving select mode",
    run = function()
      reset_case({ "alpha", "beta" }, 1, 0)
      vim.bo.commentstring = "-- %s"
      helix.select_whole_buffer()
      helix.select_regex_matches("alpha|beta")
      helix.toggle_select_mode()

      helix.toggle_line_comments()
      assert_equal(current_lines(), { "-- alpha", "-- beta" }, "toggle line comments should comment the selected lines")
      assert_equal(selection_texts(), { "alpha", "beta" }, "toggle line comments should keep selections on the original text")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "toggle line comments should leave select mode")

      helix.toggle_line_comments()
      assert_equal(current_lines(), { "alpha", "beta" }, "toggle line comments should uncomment already commented lines")
      assert_equal(selection_texts(), { "alpha", "beta" }, "uncommenting line comments should still preserve the selections")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "uncommenting line comments should stay in normal mode")
    end,
  },
  {
    name = "toggle block comments wraps and unwraps selections while leaving select mode",
    run = function()
      reset_case({ "alpha" }, 1, 0)
      vim.bo.commentstring = "// %s"
      vim.bo.comments = "s1:/*,mb:*,ex:*/,://"
      helix.select_whole_buffer()
      helix.select_regex_matches("alpha")
      helix.toggle_select_mode()

      helix.toggle_block_comments()
      assert_equal(current_lines(), { "/*alpha*/" }, "toggle block comments should wrap the selected text")
      assert_equal(selection_texts(), { "alpha" }, "toggle block comments should keep the selection on the original text")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "toggle block comments should leave select mode")

      helix.toggle_block_comments()
      assert_equal(current_lines(), { "alpha" }, "toggle block comments should unwrap an already block-commented selection")
      assert_equal(selection_texts(), { "alpha" }, "unwrapping block comments should still preserve the selection")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "unwrapping block comments should stay in normal mode")
    end,
  },
  {
    name = "increment and decrement preserve integer formatting and leave select mode",
    run = function()
      reset_case({ "099", "0xff", "0b0011", "1_999" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("099|0xff|0b0011|1_999")
      helix.toggle_select_mode()

      helix.increment()
      assert_equal(current_lines(), { "100", "0x100", "0b0100", "2_000" }, "control-a should increment decimal, hex, binary, and underscored integers")
      assert_equal(selection_texts(), { "100", "0x100", "0b0100", "2_000" }, "control-a should keep selections on the incremented values")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "control-a should leave select mode after a successful increment")

      helix.decrement()
      assert_equal(current_lines(), { "99", "0x0ff", "0b0011", "1_999" }, "control-x should decrement the current integer selections")
      assert_equal(selection_texts(), { "99", "0x0ff", "0b0011", "1_999" }, "control-x should keep selections on the decremented values")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "control-x should stay in normal mode after decrementing")
    end,
  },
  {
    name = "increment with hash register offsets each selection",
    run = function()
      reset_case({ "1", "1", "1" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("1")
      helix.select_register("#")

      helix.increment()
      assert_equal(current_lines(), { "2", "3", "4" }, "quote-hash control-a should increase the increment amount for each successive selection")
      assert_equal(selection_texts(), { "2", "3", "4" }, "quote-hash control-a should keep selections on the updated values")
    end,
  },
  {
    name = "hash paste uses buffer order instead of primary order",
    run = function()
      reset_case({ "x", "x", "x" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("x")
      helix.rotate_selections("forward")

      helix.paste_before("#")
      assert_equal(current_lines(), { "1x", "2x", "3x" }, "quote-hash paste should insert selection indices in buffer order even when the primary selection moved")
    end,
  },
  {
    name = "format selections uses lsp range formatting and preserves selection",
    run = function()
      reset_case({ "alpha", "beta" }, 1, 0)
      helix.select_whole_buffer()

      local original_get_clients = vim.lsp.get_clients
      local original_format = vim.lsp.buf.format
      vim.lsp.get_clients = function(opts)
        if opts and opts.method == "textDocument/rangeFormatting" then
          return { { id = 1, name = "fake" } }
        end
        return {}
      end

      local captured_range = nil
      vim.lsp.buf.format = function(opts)
        captured_range = opts.range
        vim.api.nvim_buf_set_text(0, 1, 0, 1, 0, { "  " })
        vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { "  " })
      end

      local ok, err = pcall(function()
        helix.format_selections()
      end)
      vim.lsp.get_clients = original_get_clients
      vim.lsp.buf.format = original_format
      if not ok then
        error(err)
      end

      assert_equal(
        captured_range,
        { start = { 1, 0 }, ["end"] = { 2, 4 } },
        "equal should request lsp range formatting for the current selection bounds"
      )
      assert_equal(current_lines(), { "  alpha", "  beta" }, "equal should apply the formatter edits")
      assert_equal(selection_texts(), { "alpha\n  beta" }, "equal should preserve the selection on the formatted text")
    end,
  },
  {
    name = "paste after in select mode preserves selections and exits to normal mode",
    run = function()
      reset_case({ "." }, 1, 0)
      helix.select_whole_buffer()
      helix.yank_selection("a")

      reset_case({ "aa aa" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("aa")
      helix.toggle_select_mode()

      helix.paste_after("a")

      assert_equal(current_lines(), { "aa. aa." }, "p in select mode should insert after each selection without selecting the inserted text")
      assert_equal(selection_texts(), { "aa", "aa" }, "p in select mode should keep the original selections")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "p in select mode should leave select mode")
    end,
  },
  {
    name = "paste before in select mode preserves selections and exits to normal mode",
    run = function()
      reset_case({ "." }, 1, 0)
      helix.select_whole_buffer()
      helix.yank_selection("b")

      reset_case({ "aa aa" }, 1, 0)
      helix.select_whole_buffer()
      helix.select_regex_matches("aa")
      helix.toggle_select_mode()

      helix.paste_before("b")

      assert_equal(current_lines(), { ".aa .aa" }, "P in select mode should insert before each selection without selecting the inserted text")
      assert_equal(selection_texts(), { "aa", "aa" }, "P in select mode should keep the original selections")
      assert_equal(vim.g.helix_mode_label, "NORMAL", "P in select mode should leave select mode")
    end,
  },
  {
    name = "R replaces current grapheme at lone cursor",
    run = function()
      reset_case({ "a" }, 1, 0)
      helix.select_whole_buffer()
      helix.yank_selection('"')

      reset_case({ "xbc" }, 1, 0)
      helix.replace_selection_with_yank('"')
      assert_equal(current_lines(), { "abc" }, "R should replace the current grapheme under a lone cursor")
      assert_equal(selection_texts(), { "a" }, "R should leave the replaced text selected")
    end,
  },
  {
    name = "linewise paste after deletes inserts below current line",
    run = function()
      reset_case({ "alpha", "beta", "gamma" }, 2, 0)

      helix.extend_line_below()
      helix.delete("a")
      assert_equal(current_lines(), { "alpha", "gamma" }, "x d should delete the selected whole line")

      helix.paste_after("a")
      assert_equal(current_lines(), { "alpha", "gamma", "beta" }, "p should paste a deleted whole line below the current line")
      assert_equal(selection_texts(), { "beta" }, "p should leave the pasted line selected")
    end,
  },
  {
    name = "linewise paste after on last line appends a new line",
    run = function()
      reset_case({ "alpha", "beta" }, 1, 0)
      helix.extend_line_below()
      helix.yank_selection("a")

      reset_case({ "alpha", "beta" }, 2, 0)
      helix.paste_after("a")
      assert_equal(current_lines(), { "alpha", "beta", "alpha" }, "p should append a linewise yank below the last line")
      assert_equal(selection_texts(), { "alpha" }, "p should select the appended line")
    end,
  },
  {
    name = "leader R replaces current grapheme from clipboard at lone cursor",
    run = function()
      reset_case({ "a" }, 1, 0)
      helix.select_whole_buffer()
      helix.yank_selection("+")

      reset_case({ "ybc" }, 1, 0)
      helix.replace_selection_with_yank("+")
      assert_equal(current_lines(), { "abc" }, "leader R should replace the current grapheme from the clipboard register")
      assert_equal(selection_texts(), { "a" }, "leader R should leave the replaced text selected")
    end,
  },
  {
    name = "gf auto-detects quoted relative paths at a lone cursor",
    run = function()
      local dir = vim.fn.tempname()
      local main = dir .. "/main.txt"
      local child = dir .. "/README.md"

      vim.fn.mkdir(dir, "p")
      vim.fn.writefile({ 'see "README.md" here' }, main)
      vim.fn.writefile({ "child" }, child)
      vim.cmd.edit(vim.fn.fnameescape(main))
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      local ok, err = pcall(helix.goto_file_targets)
      assert_equal(ok, true, "gf should not error at a lone cursor on a quoted path: " .. tostring(err))
      assert_equal(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), vim.fs.normalize(child), "gf should open the detected relative path near the cursor")
    end,
  },
  {
    name = "gf auto-detects quoted relative paths from the closing quote",
    run = function()
      local dir = vim.fn.tempname()
      local main = dir .. "/main.txt"
      local child = dir .. "/README.md"

      vim.fn.mkdir(dir, "p")
      vim.fn.writefile({ 'see "README.md" here' }, main)
      vim.fn.writefile({ "child" }, child)
      vim.cmd.edit(vim.fn.fnameescape(main))
      vim.api.nvim_win_set_cursor(0, { 1, 14 })

      local ok, err = pcall(helix.goto_file_targets)
      assert_equal(ok, true, "gf should not error at a lone cursor on the closing quote: " .. tostring(err))
      assert_equal(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), vim.fs.normalize(child), "gf should open the detected relative path from the closing quote too")
    end,
  },
  {
    name = "gf auto-detects whole filename-like token at a lone cursor",
    run = function()
      local dir = vim.fn.tempname()
      local main = dir .. "/main.txt"
      local child = dir .. "/intended,"

      vim.fn.mkdir(dir, "p")
      vim.fn.writefile({ "move intended, later" }, main)
      vim.cmd.edit(vim.fn.fnameescape(main))
      vim.api.nvim_win_set_cursor(0, { 1, 7 })

      local ok, err = pcall(helix.goto_file_targets)
      assert_equal(ok, true, "gf should not error at a lone cursor on a filename-like token: " .. tostring(err))
      assert_equal(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), vim.fs.normalize(child), "gf should open the whole filename-like token near the cursor, not just one character")
    end,
  },
  {
    name = "gf auto-detects whole filename-like token from a single-cell selection",
    run = function()
      local dir = vim.fn.tempname()
      local main = dir .. "/main.txt"
      local child = dir .. "/intended,"

      vim.fn.mkdir(dir, "p")
      vim.fn.writefile({ "move intended, later" }, main)
      vim.cmd.edit(vim.fn.fnameescape(main))
      vim.api.nvim_win_set_cursor(0, { 1, 7 })
      helix.toggle_select_mode()

      local ok, err = pcall(helix.goto_file_targets)
      assert_equal(ok, true, "gf should not error from a single-cell selection inside a filename-like token: " .. tostring(err))
      assert_equal(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), vim.fs.normalize(child), "gf should auto-detect the whole token from a single-cell selection, not open the selected character")
    end,
  },
  {
    name = "gf trims explicit selections before opening files",
    run = function()
      local dir = vim.fn.tempname()
      local main = dir .. "/main.txt"
      local child = dir .. "/notes.md"

      vim.fn.mkdir(dir, "p")
      vim.fn.writefile({ "notes.md" }, child)
      vim.fn.writefile({ "  notes.md  " }, main)
      vim.cmd.edit(vim.fn.fnameescape(main))

      helix.select_whole_buffer()
      helix.goto_file_targets()

      assert_equal(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), vim.fs.normalize(child), "gf should trim selected paths before opening them")
    end,
  },
}

local jumplist_cases = {
  {
    name = "save selection records a manual jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha beta" }, 1, 0)
        assert_jumplist_push("manual", "save_selection_to_jumplist", function()
          helix.save_selection_to_jumplist()
        end)
      end)
    end,
  },
  {
    name = "search forward records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha beta alpha" }, 1, 0)
        assert_jumplist_push("search", "search_regex", function()
          helix.search_regex()
          feed_deferred("beta<CR>")
        end)
      end)
    end,
  },
  {
    name = "search backward records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha beta alpha" }, 1, 15)
        assert_jumplist_push("search", "search_regex_backward", function()
          helix.search_regex_backward()
          feed_deferred("beta<CR>")
        end)
      end)
    end,
  },
  {
    name = "search next records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha beta alpha beta" }, 1, 0)
        helix.search_regex()
        feed_deferred("beta<CR>")
        assert_jumplist_push("search-next", "search_next", function()
          helix.search_next("forward")
        end)
      end)
    end,
  },
  {
    name = "flash jump records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha beta gamma" }, 1, 0)
        with_stubbed_getcharstr({ "b", "a" }, function()
          assert_jumplist_push("flash-jump", "flash_jump", function()
            helix.flash_jump()
          end)
        end)
      end)
    end,
  },
  {
    name = "flash treesitter records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "return foo(bar)" }, 1, 11)
        start_treesitter("lua")
        with_stubbed_getcharstr("a", function()
          assert_jumplist_push("flash-treesitter", "flash_treesitter", function()
            helix.flash_treesitter()
          end)
        end)
      end)
    end,
  },
  {
    name = "goto last line records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "one", "two", "three" }, 1, 0)
        assert_jumplist_push("goto-last-line", "goto_last_line", function()
          helix.goto_last_line()
        end)
      end)
    end,
  },
  {
    name = "goto line records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "one", "two", "three" }, 1, 0)
        assert_jumplist_push("goto-line", "goto_line", function()
          helix.goto_line()
        end)
      end)
    end,
  },
  {
    name = "goto file start records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "one", "two", "three" }, 3, 0)
        assert_jumplist_push("goto-file-start", "goto_file_start", function()
          helix.goto_file_start()
        end)
      end)
    end,
  },
  {
    name = "goto column records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "abcdef" }, 1, 5)
        assert_jumplist_push("goto-column", "goto_column", function()
          helix.goto_column()
        end)
      end)
    end,
  },
  {
    name = "goto last accessed file records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha" }, 1, 0)
        vim.cmd("enew!")
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "beta" })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        assert_jumplist_push("last-accessed-file", "goto_last_accessed_file", function()
          helix.goto_last_accessed_file()
        end)
      end)
    end,
  },
  {
    name = "goto last modified file records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha" }, 1, 0)
        local modified = vim.api.nvim_get_current_buf()
        feed("A!<Esc>")
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = modified })
        vim.cmd("enew!")
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "beta" })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        assert_jumplist_push("last-modified-file", "goto_last_modified_file", function()
          helix.goto_last_modified_file()
        end)
      end)
    end,
  },
  {
    name = "goto last modification records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha", "beta" }, 1, 0)
        feed("A!<Esc>")
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        assert_jumplist_push("last-modification", "goto_last_modification", function()
          helix.goto_last_modification()
        end)
      end)
    end,
  },
  {
    name = "goto diagnostic records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha", "oops", "beta" }, 1, 0)
        local ns = vim.api.nvim_create_namespace("motion-test-jumplist-diagnostic")
        vim.diagnostic.set(ns, 0, {
          { lnum = 1, col = 0, end_lnum = 1, end_col = 4, message = "oops", severity = vim.diagnostic.severity.ERROR },
        })
        assert_jumplist_push("diagnostic", "goto_diagnostic", function()
          helix.goto_diagnostic("forward")
        end)
      end)
    end,
  },
  {
    name = "goto edge diagnostic records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha", "oops", "beta", "warn" }, 2, 0)
        local ns = vim.api.nvim_create_namespace("motion-test-jumplist-edge-diagnostic")
        vim.diagnostic.set(ns, 0, {
          { lnum = 1, col = 0, end_lnum = 1, end_col = 4, message = "oops", severity = vim.diagnostic.severity.ERROR },
          { lnum = 3, col = 0, end_lnum = 3, end_col = 4, message = "warn", severity = vim.diagnostic.severity.WARN },
        })
        assert_jumplist_push("diagnostic-edge", "goto_edge_diagnostic", function()
          helix.goto_edge_diagnostic("last")
        end)
      end)
    end,
  },
  {
    name = "goto change records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        local cache = require("gitsigns.cache").cache
        reset_case({ "one", "two", "three", "four" }, 1, 0)
        local bufnr = vim.api.nvim_get_current_buf()
        cache[bufnr] = {
          get_hunks = function()
            return {
              {
                added = { start = 2, count = 2 },
                vend = 3,
              },
            }
          end,
        }
        assert_jumplist_push("change", "goto_change", function()
          helix.goto_change("next")
        end)
        cache[bufnr] = nil
      end)
    end,
  },
  {
    name = "goto textobject records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({
          "",
          "ChangeResult Executable::setToLive() {",
          "  if (live)",
          "    return ChangeResult::NoChange;",
          "  live = true;",
          "  return ChangeResult::Change;",
          "}",
        }, 1, 0)
        start_treesitter("cpp")
        assert_jumplist_push("textobject", "goto_textobject", function()
          helix.goto_textobject("function", "forward")
        end)
      end)
    end,
  },
  {
    name = "goto treesitter sibling records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "return foo, bar, baz" }, 1, 8)
        start_treesitter("lua")
        assert_jumplist_push("treesitter-sibling", "goto_treesitter_sibling", function()
          helix.goto_treesitter_sibling("forward")
        end)
      end)
    end,
  },
  {
    name = "goto treesitter sibling edge records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "return foo, bar, baz" }, 1, 12)
        start_treesitter("lua")
        assert_jumplist_push("treesitter-sibling-edge", "goto_treesitter_sibling_edge", function()
          helix.goto_treesitter_sibling_edge("last")
        end)
      end)
    end,
  },
  {
    name = "goto treesitter child records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "return foo(bar, baz)" }, 1, 11)
        start_treesitter("lua")
        with_stubbed_getcharstr({ "z", "z" }, function()
          helix.select_around_pair()
          helix.select_around_pair()
        end)
        assert_jumplist_push("treesitter-child", "goto_treesitter_child", function()
          helix.goto_treesitter_child("last")
        end)
      end)
    end,
  },
  {
    name = "goto paragraph records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha", "beta", "", "gamma" }, 1, 0)
        assert_jumplist_push("paragraph", "goto_paragraph", function()
          helix.goto_paragraph("forward")
        end)
      end)
    end,
  },
  {
    name = "select regex records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha beta alpha" }, 1, 0)
        helix.select_whole_buffer()
        assert_jumplist_push("select-regex", "select_regex_matches", function()
          helix.select_regex_matches("alpha")
        end)
      end)
    end,
  },
  {
    name = "keep selections records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha beta gamma" }, 1, 0)
        helix.select_whole_buffer()
        helix.select_regex_matches("alpha|beta")
        with_stubbed_input("alpha", function()
          assert_jumplist_push("keep-selections", "filter_selections_by_regex keep", function()
            helix.filter_selections_by_regex(true)
          end)
        end)
      end)
    end,
  },
  {
    name = "remove selections records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha beta gamma" }, 1, 0)
        helix.select_whole_buffer()
        helix.select_regex_matches("alpha|beta")
        with_stubbed_input("alpha", function()
          assert_jumplist_push("remove-selections", "filter_selections_by_regex remove", function()
            helix.filter_selections_by_regex(false)
          end)
        end)
      end)
    end,
  },
  {
    name = "goto match records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "foo(bar)" }, 1, 3)
        assert_jumplist_push("match", "goto_match", function()
          helix.goto_match()
        end)
      end)
    end,
  },
  {
    name = "split selection by line records a jumplist entry",
    run = function()
      with_fresh_jumplist_tab(function()
        reset_case({ "alpha", "beta", "gamma" }, 1, 0)
        helix.select_whole_buffer()
        assert_jumplist_push("split-selection-by-line", "split_selection_by_line", function()
          helix.split_selection_by_line()
        end)
      end)
    end,
  },
}

for _, case in ipairs(jumplist_cases) do
  cases[#cases + 1] = case
end

for _, case in ipairs(cases) do
  case.run()
end

print("motion-tests-ok")
