local helix = require("axelcool1234.helix")
local state = require("axelcool1234.helix.state")

local function assert_equal(actual, expected, label)
  if not vim.deep_equal(actual, expected) then
    error(label .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual))
  end
end

local function reset(lines, row, col0)
  vim.cmd("enew!")
  vim.bo.filetype = "text"
  local undolevels = vim.bo.undolevels
  vim.bo.undolevels = -1
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.undolevels = undolevels
  vim.api.nvim_win_set_cursor(0, { row or 1, col0 or 0 })
end

local function selection_texts()
  local texts = {}
  for _, entry in ipairs(helix.current_selection_entries()) do
    texts[#texts + 1] = state.get_entry_text(entry)
  end
  return texts
end

local basic_cases = {
  { name = "w word", target = "next_word_start", text = "alpha beta", col0 = 0, expected = "alpha " },
  { name = "e word", target = "next_word_end", text = "alpha beta", col0 = 0, expected = "alpha" },
  { name = "b word", target = "prev_word_start", text = "alpha beta", col0 = 6, expected = "alpha " },
  { name = "W long word", target = "next_long_word_start", text = "alpha.!,and next", col0 = 0, expected = "alpha.!,and " },
  { name = "E long word", target = "next_long_word_end", text = "alpha.!,and next", col0 = 0, expected = "alpha.!,and" },
  { name = "B long word", target = "prev_long_word_start", text = "alpha.!,and next", col0 = 12, expected = "alpha.!,and " },
  { name = "w punctuation boundary", target = "next_word_start", text = "alpha.!,and", col0 = 0, expected = "alpha" },
  { name = "e punctuation boundary", target = "next_word_end", text = "alpha.!,and", col0 = 5, expected = ".!," },
  { name = "w underscore word", target = "next_word_start", text = "one_two next", col0 = 0, expected = "one_two " },
  { name = "W keeps punctuation", target = "next_long_word_start", text = "...   next", col0 = 0, expected = "...   " },
  { name = "E stops before whitespace", target = "next_long_word_end", text = "...   next", col0 = 0, expected = "..." },
  { name = "b punctuation", target = "prev_word_start", text = "alpha.!,and", col0 = 8, expected = ".!," },
}

for _, case in ipairs(basic_cases) do
  reset({ case.text }, 1, case.col0)
  helix.apply_word_motion(case.target)
  assert_equal(selection_texts(), { case.expected }, case.name)
end

do
  reset({ "one two three four" })
  helix.apply_word_motion("next_word_start", 3)
  assert_equal(selection_texts(), { "three " }, "counted w should select the final traversed segment")

  reset({ "one two" })
  helix.apply_word_motion("next_word_start", 999)
  assert_equal(selection_texts(), { "two" }, "excessive w counts should retain the final partial motion")

  reset({ "one two" }, 1, 6)
  helix.apply_word_motion("prev_word_start", 999)
  assert_equal(selection_texts(), { "one " }, "excessive b counts should retain the final partial motion")
end

do
  local text = "one.!,two three four"
  local counted_cases = {
    { target = "next_word_start", col0 = 0 },
    { target = "next_word_end", col0 = 0 },
    { target = "prev_word_start", col0 = #text - 1 },
    { target = "next_long_word_start", col0 = 0 },
    { target = "next_long_word_end", col0 = 0 },
    { target = "prev_long_word_start", col0 = #text - 1 },
  }
  for _, case in ipairs(counted_cases) do
    reset({ text }, 1, case.col0)
    helix.apply_word_motion(case.target, 2)
    local counted = helix.current_selection_entries()

    reset({ text }, 1, case.col0)
    helix.apply_word_motion(case.target)
    helix.apply_word_motion(case.target)
    assert_equal(helix.current_selection_entries(), counted, case.target .. " count should match two successive motions")
  end
end

do
  for _, target in ipairs({
    "next_word_start",
    "next_word_end",
    "prev_word_start",
    "next_long_word_start",
    "next_long_word_end",
    "prev_long_word_start",
  }) do
    reset({ "" })
    local before = helix.current_selection_entries()
    helix.apply_word_motion(target)
    assert_equal(helix.current_selection_entries(), before, target .. " should be a no-op in an empty buffer")
  end

  reset({ "last" }, 1, 3)
  local before = helix.current_selection_entries()
  helix.apply_word_motion("next_word_start")
  assert_equal(helix.current_selection_entries(), before, "a failed forward motion should preserve the selection")

  reset({ "first" }, 1, 0)
  before = helix.current_selection_entries()
  helix.apply_word_motion("prev_word_start")
  assert_equal(helix.current_selection_entries(), before, "a failed backward motion should preserve the selection")
end

do
  reset({ "one", "", "", "   two" })
  helix.apply_word_motion("next_word_start", 2)
  assert_equal(helix.primary_selection_entry().cursor_pos, { 4, 3 }, "w should bridge newline groups and leading whitespace")

  reset({ "", "", "" })
  helix.apply_word_motion("next_word_start")
  assert_equal(helix.primary_selection_entry().cursor_pos, { 3, 1 }, "w should traverse an all-newline buffer")

  reset({ "ヒーリクス 次" })
  helix.apply_word_motion("next_word_start")
  assert_equal(selection_texts(), { "ヒーリクス " }, "w should group multibyte letters as a word")

  reset({ "éclair.次" })
  helix.apply_word_motion("next_word_start")
  assert_equal(selection_texts(), { "éclair" }, "w should distinguish a Unicode word from punctuation")
end

do
  reset({ "one two", "three four" })
  helix.select_whole_buffer()
  helix.select_regex_matches("^o|^t")
  helix.apply_word_motion("next_word_start")
  assert_equal(selection_texts(), { "one ", "three " }, "w should move every cursor independently")

  reset({ "one two three" })
  helix.toggle_select_mode()
  local anchor = vim.deepcopy(helix.primary_selection_entry().anchor_pos)
  helix.apply_word_motion("next_word_start", 2)
  assert_equal(helix.primary_selection_entry().anchor_pos, anchor, "select-mode w should retain its original anchor")
  assert_equal(selection_texts(), { "one two " }, "select-mode counted w should extend through every segment")
end

print("word-motion-tests-ok")
