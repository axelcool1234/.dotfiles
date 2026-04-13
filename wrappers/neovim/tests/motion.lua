local helix = require("axelcool1234.helix")

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

local function feed(keys)
  local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(termcodes, "xt", false)
  vim.wait(150)
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
}

for _, case in ipairs(cases) do
  case.run()
end

print("motion-tests-ok")
