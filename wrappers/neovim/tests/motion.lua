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
    name = "backward search starts backward but n and N keep fixed directions",
    run = function()
      reset_case({ "alpha beta alpha gamma alpha" }, 1, 17)

      local original_input = vim.fn.input
      vim.fn.input = function()
        return "alpha"
      end

      local ok, err = pcall(function()
        helix.search_regex_backward()
      end)
      vim.fn.input = original_input
      if not ok then
        error(err)
      end

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
      helix.toggle_select_mode()
      helix.goto_change("next")
      assert_equal(selection_texts(), { "one\ntwo\nthree\n" }, "]g in select mode should extend from the anchor through the hunk")

      reset_case({ "one", "two", "three", "four" }, 4, 0)
      bufnr = vim.api.nvim_get_current_buf()
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
      helix.toggle_select_mode()
      helix.goto_change("prev")
      assert_equal(selection_texts(), { "two\nthree\nf" }, "[g in select mode should extend to the start of the previous hunk")
      cache[bufnr] = nil
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

for _, case in ipairs(cases) do
  case.run()
end

print("motion-tests-ok")
