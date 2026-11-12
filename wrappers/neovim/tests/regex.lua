local helix = require("axelcool1234.helix")
local position = require("axelcool1234.helix.position")
local state_module = require("axelcool1234.helix.state")

vim.o.virtualedit = "onemore"

local passed, failures = 0, {}

local function equal(actual, expected, label)
  if not vim.deep_equal(actual, expected) then
    error(label .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual))
  end
end

local function test(name, run)
  local ok, err = pcall(run)
  if ok then
    passed = passed + 1
  else
    failures[#failures + 1] = name .. ": " .. tostring(err)
  end
end

local function reset(lines, first, last, backward)
  helix.exit_select_mode()
  vim.cmd("enew!")
  vim.bo.filetype = "text"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  first = first or { 1, 1 }
  last = last or { #lines, position.grapheme_count(lines[#lines]) }
  local start, finish = backward and last or first, backward and first or last
  state_module.move_cursor_to_pos(start)
  helix.toggle_select_mode()
  local motion = helix.normal_motion(backward and "h" or "l")
  local steps = 0
  while not position.cells_equal(helix.primary_range():cursor(), finish) do
    motion()
    steps = steps + 1
    assert(steps < 200, "selection setup did not reach its endpoint")
  end
end

local function shape()
  local selection = helix.current_selection()
  local ranges = {}
  for index, range in ipairs(selection.ranges) do
    ranges[index] = { range.anchor, range.head, range.kind }
  end
  return { ranges = ranges, primary = selection.primary_index, mode = vim.g.helix_mode_label }
end

local function selected(expected)
  local selection = helix.current_selection()
  equal(selection:texts(), expected, "selected text")
  equal(state_module.current_pos_1indexed(), selection:primary():cursor(), "logical and rendered primary cursor")
  for _, range in ipairs(selection.ranges) do
    local sr, sc, er, ec = range:byte_range()
    equal(vim.api.nvim_buf_get_text(0, sr, sc, er, ec, {}), vim.split(range:text(), "\n", { plain = true }), "byte range round trip")
  end
end

local function filter(pattern, keep)
  local original = vim.fn.input
  vim.fn.input = function() return pattern end
  local ok, err = pcall(helix.filter_selections_by_regex, keep)
  vim.fn.input = original
  assert(ok, err)
end

-- Exhaust every nonempty interval, in both directions. The oracle examines the
-- original cells, independently of the regex slicing and byte-offset code.
for _, lines in ipairs({ { "()x()" }, { "α(é)中()" }, { "(👍🏽)(🇺🇸)" }, { "(α)", "", "(é)" } }) do
  local cells = {}
  for row, line in ipairs(lines) do
    for col = 1, position.grapheme_count(line) + (row < #lines and 1 or 0) do
      cells[#cells + 1] = { pos = { row, col }, char = position.grapheme_at(line, col) }
    end
  end
  for first = 1, #cells do
    for last = first, #cells do
      for _, backward in ipairs({ false, true }) do
        test(("interval %s %d:%d %s"):format(table.concat(lines, "\\n"), first, last, tostring(backward)), function()
          reset(lines, cells[first].pos, cells[last].pos, backward)
          local before = shape()
          local texts, cursors = {}, {}
          for col = first, last do
            local char = cells[col].char
            if char == "(" or char == ")" then
              texts[#texts + 1] = char
              cursors[#cursors + 1] = cells[col].pos
            end
          end
          helix.select_regex_matches("[()]")
          if #texts == 0 then
            equal(shape(), before, "no match must retain the selection")
          else
            selected(texts)
            for index, range in ipairs(helix.current_selection().ranges) do
              equal(range:cursor(), cursors[index], "match cell inside the original interval")
            end
          end
        end)
      end
    end
  end
end

local cases = {
  { "full cluster", { "pre é中👍🏽 tail" }, { 1, 5 }, { 1, 7 }, "é|中|👍🏽", { "é", "中", "👍🏽" } },
  { "combining-insensitive match", { "pre éx tail" }, { 1, 5 }, { 1, 6 }, "e\\Z", { "é" } },
  { "adjacent multibyte matches", { "pre ααα tail" }, { 1, 5 }, { 1, 7 }, "α", { "α", "α", "α" } },
  { "dot selects complete graphemes", { "é👨‍👩‍👧‍👦🇺🇸👍🏽" }, { 1, 1 }, { 1, 4 }, ".", { "é", "👨‍👩‍👧‍👦", "🇺🇸", "👍🏽" } },
  { "empty match after consuming match", { "abc" }, { 1, 1 }, { 1, 3 }, "a*", { "a", "" } },
  { "no adjacent empty match", { "ab" }, { 1, 1 }, { 1, 2 }, "a*", { "a" } },
  { "greedy bounded match", { "zaaaaaaz" }, { 1, 3 }, { 1, 5 }, "a+", { "aaa" } },
  { "alternation bounded match", { "zabcdefz" }, { 1, 3 }, { 1, 4 }, "bcde|bc", { "bc" } },
  { "literal escaped anchors", { "pre ^[$] tail" }, { 1, 5 }, { 1, 9 }, "\\^|\\$", { "^", "$" } },
  { "anchors in character class", { "pre ^$ tail" }, { 1, 5 }, { 1, 6 }, "[^a-z ]", { "^", "$" } },
  { "POSIX character class", { "a^$." }, { 1, 1 }, { 1, 4 }, "[[:alpha:]^$.]", { "a", "^", "$", "." } },
  { "literal closing bracket in class", { "]^$." }, { 1, 1 }, { 1, 4 }, "[]^$.]", { "]", "^", "$", "." } },
  { "anchors retain capture numbers", { "aa", "bb" }, { 1, 1 }, { 2, 2 }, "^(a)\\1$", { "aa" } },
  { "very nomagic literals", { "pre ^.$[] tail" }, { 1, 5 }, { 1, 9 }, "\\V^.$[]", { "^.$[]" } },
  { "no invented start anchor", { "prefix abc suffix" }, { 1, 8 }, { 1, 10 }, "^abc", nil },
  { "no invented end anchor", { "prefix abc suffix" }, { 1, 8 }, { 1, 10 }, "abc$", nil },
  { "no invented word boundary", { "foobar" }, { 1, 4 }, { 1, 6 }, "<bar", nil },
  { "multiline clipped edges", { "(outside) (α)", "", "(é) (outside)" }, { 1, 11 }, { 3, 3 }, "\\(", { "(", "(" } },
  { "newline match", { "αx", "yβ" }, { 1, 2 }, { 2, 1 }, "\\n", { "\n" } },
  { "match spanning newline", { "pre αx", "yβ tail" }, { 1, 5 }, { 2, 2 }, "x\\ny", { "x\ny" } },
  { "dot excludes newline", { "a", "b" }, { 1, 1 }, { 2, 1 }, ".", { "a", "b" } },
  { "start anchors on real lines", { "ab", "cd" }, { 1, 1 }, { 2, 2 }, "^.", { "a", "c" } },
  { "end anchors on real lines", { "ab", "cd" }, { 1, 1 }, { 2, 2 }, ".$", { "b", "d" } },
  { "empty start match", { "abc" }, { 1, 1 }, { 1, 3 }, "^", { "" } },
  { "empty match before newline", { "abc", "d" }, { 1, 1 }, { 1, 4 }, "$", { "" } },
  { "exclusive end empty match", { "abc" }, { 1, 1 }, { 1, 3 }, "$", nil },
  { "empty alternatives", { "αβ" }, { 1, 1 }, { 1, 2 }, "z*", { "", "" } },
  { "blank line anchor", { "a", "", "b" }, { 1, 1 }, { 3, 1 }, "^$", { "" } },
  { "empty buffer", { "" }, { 1, 1 }, { 1, 1 }, ".", nil },
}

for _, case in ipairs(cases) do
  for _, backward in ipairs({ false, true }) do
    test(case[1] .. " backward=" .. tostring(backward), function()
      reset(case[2], case[3], case[4], backward)
      local before = shape()
      helix.select_regex_matches(case[5])
      if case[6] then
        selected(case[6])
        if case[6][1] == "" then
          for _, range in ipairs(helix.current_selection().ranges) do
            assert(range:is_empty(), "zero-width regex matches must remain empty")
          end
        end
      else
        equal(shape(), before, "unsuccessful regex must preserve every range and its direction")
      end
    end)
  end
end

for _, backward in ipairs({ false, true }) do
  for _, case in ipairs({
    { "leading delimiter", ",ab", ",", { "", "ab" } },
    { "trailing delimiter", "ab,", ",", { "ab" } },
    { "all delimiter", ",", ",", { "" } },
    { "Unicode delimiter", "α,é,中", ",", { "α", "é", "中" } },
    { "consecutive delimiters", "α,,β", ",", { "α", "", "β" } },
    { "empty delimiter", "αβ", "z*", { "α", "β" } },
    { "anchored empty delimiter", "ab", "^", { "ab" } },
  }) do
    test("split " .. case[1] .. " backward=" .. tostring(backward), function()
      local line = "prefix " .. case[2] .. " suffix"
      -- ^ refers to the real line start, so this case selects the whole line.
      if case[1] == "anchored empty delimiter" then line = case[2] end
      local first = case[1] == "anchored empty delimiter" and 1 or 8
      reset({ line }, { 1, first }, { 1, first + position.grapheme_count(case[2]) - 1 }, backward)
      helix.split_selection_by_regex(case[3])
      selected(case[4])
      for _, range in ipairs(helix.current_selection().ranges) do
        if not range:is_empty() then
          equal(range:direction(), backward and -1 or 1, "split retains source direction")
        end
      end
    end)
  end
end

test("repeated select operates separately on each range", function()
  reset({ "outside (α) outside (é) outside" })
  helix.select_regex_matches("\\([^()]*\\)")
  helix.select_regex_matches("[()]")
  selected({ "(", ")", "(", ")" })
end)

for _, operation in ipairs({ helix.select_regex_matches, helix.split_selection_by_regex, function() filter("", true) end }) do
  test("cancelled prompt retains the selection", function()
    reset({ "αbc" }, { 1, 1 }, { 1, 3 }, true)
    local before = shape()
    local original = vim.fn.input
    vim.fn.input = function() return "" end
    local ok, err = pcall(operation)
    vim.fn.input = original
    assert(ok, err)
    equal(shape(), before, "cancelling must retain selection, primary and mode")
  end)
end

for _, keep in ipairs({ true, false }) do
  test("filter ignores gaps between ranges keep=" .. tostring(keep), function()
    reset({ "(α) gap (β)" })
    helix.select_regex_matches("\\([^()]*\\)")
    helix.flip_selection_direction()
    helix.rotate_selections("backward")
    local before = shape()
    filter("gap", keep)
    equal(shape(), before, "filter must not inspect the gap or lose selection state")
  end)
end

test("filter can match across a selected newline", function()
  reset({ "prefix α", "β suffix" }, { 1, 8 }, { 2, 1 }, true)
  local before = shape()
  filter("α\\nβ", true)
  equal(shape(), before, "multiline filter should retain the matching source range")
end)

for _, keep in ipairs({ true, false }) do
  test("filter isolated ranges keep=" .. tostring(keep), function()
    reset({ "(α) outside (é) outside (β)" })
    helix.select_regex_matches("\\([^()]*\\)")
    helix.rotate_selections("backward")
    helix.flip_selection_direction()
    filter("é", keep)
    selected(keep and { "(é)" } or { "(α)", "(β)" })
    equal(helix.primary_range():text(), keep and "(é)" or "(β)", "filter retains primary identity or chooses the preceding survivor")
    for _, range in ipairs(helix.current_selection().ranges) do
      equal(range:direction(), -1, "filter retains direction")
    end
  end)
end

test("empty match insertion and undo", function()
  reset({ "X" })
  helix.yank_selection("q")
  reset({ "αbc" })
  helix.select_regex_matches("^")
  selected({ "" })
  helix.replace_selection_with_yank("q")
  equal(vim.api.nvim_get_current_line(), "Xαbc", "replacing an empty match should insert without eating a grapheme")
  helix.undo()
  equal(vim.api.nvim_get_current_line(), "αbc", "undo restores original text")
  selected({ "" })
  helix.redo()
  equal(vim.api.nvim_get_current_line(), "Xαbc", "redo restores the insertion")
end)

test("multicursor deletion and undo stay inside selected parameters", function()
  reset({ "prefix (α) (é) suffix (outside)" }, { 1, 8 }, { 1, 14 })
  helix.select_regex_matches("[()]")
  selected({ "(", ")", "(", ")" })
  local before = shape()
  helix.delete("_")
  equal(vim.api.nvim_get_current_line(), "prefix α é suffix (outside)", "delete changes only the matched delimiters")
  helix.undo()
  equal(vim.api.nvim_get_current_line(), "prefix (α) (é) suffix (outside)", "undo restores the delimiters")
  equal(shape(), before, "undo restores all regex ranges")
end)

test("split ranges retain primary identity", function()
  reset({ "(α,β) (é,中)" })
  helix.select_regex_matches("\\([^()]*\\)")
  helix.rotate_selections("backward")
  helix.flip_selection_direction()
  helix.split_selection_by_regex(",")
  selected({ "(α", "β)", "(é", "中)" })
  equal(helix.primary_range():text(), "(é", "first piece of the old primary remains primary")
  for _, range in ipairs(helix.current_selection().ranges) do
    equal(range:direction(), -1, "all split pieces retain direction")
  end
end)

if #failures > 0 then
  error(("%d regex tests passed; %d failed\n%s"):format(passed, #failures, table.concat(failures, "\n")))
end
print(("regex-tests-ok (%d cases)"):format(passed))
