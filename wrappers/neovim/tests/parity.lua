local helix = require("axelcool1234.helix")
local pickers = require("axelcool1234.pickers")
local position = require("axelcool1234.helix.position")
local state_module = require("axelcool1234.helix.state")

local function assert_equal(actual, expected, label)
  if not vim.deep_equal(actual, expected) then
    error(label .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual))
  end
end

local function reset_case(lines, row, col0)
  vim.cmd("enew!")
  vim.bo.filetype = "text"
  local undo_levels = vim.o.undolevels
  vim.bo.undolevels = -1
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.undolevels = undo_levels
  vim.api.nvim_win_set_cursor(0, { row or 1, col0 or 0 })
end

local function current_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function selection_texts()
  local texts = {}
  for _, entry in ipairs(helix.current_selection_entries()) do
    texts[#texts + 1] = state_module.get_entry_text(entry)
  end
  return texts
end

local function with_fresh_tab(run)
  vim.cmd("tabnew")
  local ok, err = xpcall(run, debug.traceback)
  vim.cmd("tabclose!")
  if not ok then
    error(err)
  end
end

local function with_getchar(value, run)
  local original = vim.fn.getcharstr
  vim.fn.getcharstr = function()
    return value
  end
  local ok, err = xpcall(run, debug.traceback)
  vim.fn.getcharstr = original
  if not ok then
    error(err)
  end
end

local function feed(keys)
  local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(termcodes, "xt", false)
end

local function start_treesitter(filetype)
  vim.bo.filetype = filetype
  assert(pcall(vim.treesitter.start, 0, filetype), "Tree-sitter parser unavailable for " .. filetype)
end

local cases = {
  {
    name = "coordinate helpers use grapheme rather than codepoint boundaries",
    run = function()
      local samples = {
        { text = "éx", next_byte = 3 },
        { text = "👨‍👩‍👧‍👦x", next_byte = 25 },
        { text = "🇺🇸x", next_byte = 8 },
        { text = "👍🏽x", next_byte = 8 },
      }
      for _, sample in ipairs(samples) do
        assert_equal(position.char_count(sample.text), 2, sample.text .. " should contain two graphemes")
        assert_equal(position.byte_col0_from_char_col(sample.text, 2), sample.next_byte, "second grapheme byte boundary")
        assert_equal(position.char_col_from_byte_col0(sample.text, sample.next_byte), 2, "byte boundary round trip")
      end
    end,
  },
  {
    name = "horizontal motions cross an entire grapheme cluster",
    run = function()
      local samples = {
        { text = "éx", next_byte = 3 },
        { text = "👨‍👩‍👧‍👦x", next_byte = 25 },
        { text = "🇺🇸x", next_byte = 8 },
        { text = "👍🏽x", next_byte = 8 },
      }
      for _, sample in ipairs(samples) do
        reset_case({ sample.text })
        helix.normal_motion("l")()
        assert_equal(vim.api.nvim_win_get_cursor(0), { 1, sample.next_byte }, "l should land on the next grapheme")
        helix.normal_motion("h")()
        assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "h should return across one grapheme")
      end
    end,
  },
  {
    name = "vertical select motions preserve visual columns across wide text",
    run = function()
      reset_case({ "パーティーへ行かないか", "The text above is Japanese" })
      for _ = 1, 4 do
        helix.normal_motion("l")()
      end
      helix.toggle_select_mode()
      helix.normal_motion("j")()
      assert_equal(helix.primary_selection_entry().cursor_pos, { 2, 9 }, "j should preserve the kana cursor's visual column")
      helix.normal_motion("k")()
      assert_equal(helix.primary_selection_entry().cursor_pos, { 1, 5 }, "k should restore the original grapheme column")
    end,
  },
  {
    name = "Unicode upper and lower case preserve transformed selections",
    run = function()
      reset_case({ "éßσ" })
      helix.select_whole_buffer()
      helix.set_selection_case("upper")
      assert_equal(current_lines(), { "ÉSSΣ" }, "uppercase should support full Unicode mappings")
      assert_equal(selection_texts(), { "ÉSSΣ" }, "uppercase should retain a length-changing selection")

      reset_case({ "İ" })
      helix.select_whole_buffer()
      helix.set_selection_case("lower")
      assert_equal(current_lines(), { "i̇" }, "lowercase should support Unicode special casing")
      assert_equal(selection_texts(), { "i̇" }, "lowercase should update selection bounds")
    end,
  },
  {
    name = "Unicode toggle case follows each grapheme and preserves expansions",
    run = function()
      reset_case({ "éΣß中" })
      helix.select_whole_buffer()
      helix.toggle_selection_case()
      assert_equal(current_lines(), { "ÉσSS中" }, "toggle case should use Unicode case properties")
      assert_equal(selection_texts(), { "ÉσSS中" }, "toggle case should retain a length-changing selection")
    end,
  },
  {
    name = "split selections preserve only Helix's leading empty range",
    run = function()
      reset_case({ " ab" })
      helix.select_whole_buffer()
      helix.split_selection_by_regex("^ ")
      assert_equal(selection_texts(), { "", "ab" }, "a leading delimiter should leave a leading empty selection")
      assert_equal(helix.current_selection_entries()[1].empty, true, "the leading point should be semantically empty")

      reset_case({ "ab " })
      helix.select_whole_buffer()
      helix.split_selection_by_regex(" $")
      assert_equal(selection_texts(), { "ab" }, "a trailing delimiter should not create an empty selection")

      reset_case({ " " })
      helix.select_whole_buffer()
      helix.split_selection_by_regex(" ")
      assert_equal(selection_texts(), { "" }, "a fully matched selection should retain one empty range")
    end,
  },
  {
    name = "consecutive merging keeps groups primary identity and direction",
    run = function()
      reset_case({ "abcd efgh" })
      helix.select_whole_buffer()
      helix.select_regex_matches("ab|cd|ef|gh")
      helix.flip_selection_direction()
      helix.merge_selections(true)
      assert_equal(selection_texts(), { "abcd", "efgh" }, "adjacent groups should merge independently")
      for _, entry in ipairs(helix.current_selection_entries()) do
        assert(entry.anchor_pos[2] > entry.cursor_pos[2], "merged reverse selections should remain reverse")
      end
      helix.merge_selections(true)
      assert_equal(selection_texts(), { "abcd", "efgh" }, "merging should be idempotent")

      reset_case({ "abcd efgh" })
      helix.select_whole_buffer()
      helix.select_regex_matches("ab|cd|ef|gh")
      helix.rotate_selections("backward")
      assert_equal(selection_texts()[1], "gh", "the last range should become primary before merging")
      helix.merge_selections(true)
      assert_equal(selection_texts()[1], "efgh", "the group containing the old primary should remain primary")
    end,
  },
  {
    name = "word motions cover word long-word punctuation and underscores",
    run = function()
      local tests = {
        { "Basic forward motion", "next_word_start", "Basic " },
        { "Identifiers_with_underscores are", "next_word_start", "Identifiers_with_underscores " },
        { "alpha.!,and next", "next_word_start", "alpha" },
        { "alpha.!,and next", "next_long_word_start", "alpha.!,and " },
        { "alpha beta", "next_word_end", "alpha" },
      }
      for _, test in ipairs(tests) do
        reset_case({ test[1] })
        helix.apply_word_motion(test[2])
        assert_equal(selection_texts(), { test[3] }, test[2] .. " should match Helix word grouping")
      end

      reset_case({ "alpha beta" }, 1, 6)
      helix.apply_word_motion("prev_word_start")
      assert_equal(selection_texts(), { "alpha " }, "previous word start should produce a reverse selection")
      assert(helix.primary_selection_entry().anchor_pos[2] > helix.primary_selection_entry().cursor_pos[2], "b should face backward")
    end,
  },
  {
    name = "word motions handle counts newlines Unicode and select mode",
    run = function()
      reset_case({ "one two three four" })
      helix.apply_word_motion("next_word_start", 3)
      assert_equal(selection_texts(), { "three " }, "counted w should select the third target word segment")

      reset_case({ "ヒーリクス next" })
      helix.apply_word_motion("next_word_start")
      assert_equal(selection_texts(), { "ヒーリクス " }, "multibyte word characters should move as one word")

      reset_case({ "one", "", "  two" })
      helix.apply_word_motion("next_word_start", 2)
      assert_equal(helix.primary_selection_entry().cursor_pos, { 3, 2 }, "word motion should bridge newline groups and leading space")

      reset_case({ "one two three" })
      helix.toggle_select_mode()
      local anchor = vim.deepcopy(helix.primary_selection_entry().anchor_pos)
      helix.apply_word_motion("next_word_start", 2)
      assert_equal(helix.primary_selection_entry().anchor_pos, anchor, "word motion in select mode should retain its anchor")
      assert_equal(selection_texts(), { "one two " }, "select-mode word motion should extend through the count")
    end,
  },
  {
    name = "find and till motions treat return as the newline cell",
    run = function()
      reset_case({ "hello", "world" })
      with_getchar("\r", function()
        helix.find_char_motion("f")()
      end)
      assert_equal(helix.primary_selection_entry().cursor_pos, { 1, 6 }, "f<ret> should land on the newline")

      reset_case({ "hello", "world" })
      with_getchar("\r", function()
        helix.find_char_motion("t")()
      end)
      assert_equal(helix.primary_selection_entry().cursor_pos, { 1, 5 }, "t<ret> should stop before the newline")
    end,
  },
  {
    name = "undo redo earlier and later restore text and multicursor selections",
    run = function()
      reset_case({ "Alpha Beta" })
      helix.select_whole_buffer()
      helix.select_regex_matches("Alpha|Beta")
      helix.flip_selection_direction()
      helix.rotate_selections("backward")
      helix.set_selection_case("upper")
      assert_equal(current_lines(), { "ALPHA BETA" }, "the edit should apply")
      helix.undo()
      assert_equal(current_lines(), { "Alpha Beta" }, "undo should restore text")
      assert_equal(selection_texts(), { "Beta", "Alpha" }, "undo should restore selections and primary identity")
      for _, entry in ipairs(helix.current_selection_entries()) do
        assert(entry.anchor_pos[2] > entry.cursor_pos[2], "undo should restore backward selection direction")
      end
      helix.redo()
      assert_equal(current_lines(), { "ALPHA BETA" }, "redo should restore text")
      assert_equal(selection_texts(), { "BETA", "ALPHA" }, "redo should restore selections and primary identity")
      helix.earlier()
      assert_equal(current_lines(), { "Alpha Beta" }, "earlier should navigate native history")
      assert_equal(selection_texts(), { "Beta", "Alpha" }, "earlier should restore multicursors and primary identity")
      for _, entry in ipairs(helix.current_selection_entries()) do
        assert(entry.anchor_pos[2] > entry.cursor_pos[2], "earlier should restore selection direction")
      end
      helix.later()
      assert_equal(current_lines(), { "ALPHA BETA" }, "later should navigate native history")
      assert_equal(selection_texts(), { "BETA", "ALPHA" }, "later should restore multicursors and primary identity")
      for _, entry in ipairs(helix.current_selection_entries()) do
        assert(entry.anchor_pos[2] > entry.cursor_pos[2], "later should restore selection direction")
      end

      helix.undo()
      helix.set_selection_case("lower")
      assert_equal(current_lines(), { "alpha beta" }, "a new edit should create a history branch")
      helix.redo()
      assert_equal(current_lines(), { "alpha beta" }, "redo should not resurrect the discarded branch")
    end,
  },
  {
    name = "undo redo earlier and later restore preferred visual columns",
    run = function()
      local navigation_cases = {
        { name = "undo", navigate = helix.undo },
        {
          name = "redo",
          navigate = function()
            helix.undo()
            helix.redo()
          end,
        },
        { name = "earlier", navigate = helix.earlier },
        {
          name = "later",
          navigate = function()
            helix.earlier()
            helix.later()
          end,
        },
      }
      for _, case in ipairs(navigation_cases) do
        with_fresh_tab(function()
          reset_case({ "abcdef", "中", "abcdef" }, 1, 1)
          helix.toggle_select_mode()
          helix.normal_motion("j")()
          assert_equal(helix.primary_selection_entry().cursor_pos, { 2, 1 }, "j should land within the wide cell")
          helix.toggle_select_mode()
          helix.collapse_selections_to_cursors()
          with_getchar("X", helix.replace_selection_with_char)
          case.navigate()
          assert_equal(helix.primary_selection_entry().cursor_pos, { 2, 1 }, case.name .. " should restore the wide-cell cursor")
          helix.normal_motion("j")()
          assert_equal(helix.primary_selection_entry().cursor_pos, { 3, 2 }, case.name .. " should restore the preferred column")
        end)
      end
    end,
  },
  {
    name = "undoing point deletes restores each delete selection before older edit selections",
    run = function()
      reset_case({ "abc", "xyz" }, 2, 0)
      helix.toggle_select_mode()
      with_getchar("X", helix.replace_selection_with_char)
      assert_equal(current_lines(), { "abc", "Xyz" }, "the older edit should apply on the second line")

      helix.keep_primary_selection_or_cursor()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      feed("dd")
      assert_equal(current_lines(), { "c", "Xyz" }, "two point deletes should apply on the first line")

      helix.undo()
      assert_equal(current_lines(), { "bc", "Xyz" }, "the first undo should restore the second deleted character")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "the first delete undo should stay on its line")
      helix.undo()
      assert_equal(current_lines(), { "abc", "Xyz" }, "the second undo should restore the first deleted character")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "the final delete undo should not jump to the older edit")

      helix.undo()
      assert_equal(current_lines(), { "abc", "xyz" }, "the next undo should restore the older edit")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 0 }, "undoing the older edit should restore its own selection")

      helix.redo()
      assert_equal(current_lines(), { "abc", "Xyz" }, "redo should reapply the older edit")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 0 }, "redoing the older edit should restore its resulting selection")
      helix.redo()
      assert_equal(current_lines(), { "bc", "Xyz" }, "redo should reapply the first point delete")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "redoing the first delete should restore its resulting selection")
      helix.redo()
      assert_equal(current_lines(), { "c", "Xyz" }, "redo should reapply the second point delete")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "redoing the second delete should stay on its line")
    end,
  },
  {
    name = "point replace and newline edits keep their undo selections separate from older edits",
    run = function()
      local edit_cases = {
        {
          name = "point replace",
          apply = function()
            with_getchar("Q", helix.replace_selection_with_char)
          end,
          changed = { "Qbc", "Xyz" },
          cursor = { 1, 0 },
        },
        {
          name = "add newline below",
          apply = function()
            feed("]<Space>")
          end,
          changed = { "abc", "", "Xyz" },
          cursor = { 1, 0 },
        },
        {
          name = "add newline above",
          apply = function()
            feed("[<Space>")
          end,
          changed = { "", "abc", "Xyz" },
          cursor = { 2, 0 },
        },
      }

      for _, case in ipairs(edit_cases) do
        with_fresh_tab(function()
          reset_case({ "abc", "xyz" }, 2, 0)
          helix.toggle_select_mode()
          with_getchar("X", helix.replace_selection_with_char)
          helix.keep_primary_selection_or_cursor()
          vim.api.nvim_win_set_cursor(0, { 1, 0 })

          case.apply()
          assert_equal(current_lines(), case.changed, case.name .. " should apply")
          assert_equal(vim.api.nvim_win_get_cursor(0), case.cursor, case.name .. " should remap its cursor")
          helix.undo()
          assert_equal(current_lines(), { "abc", "Xyz" }, case.name .. " should undo independently")
          assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, case.name .. " undo should stay on its edit line")

          helix.undo()
          assert_equal(current_lines(), { "abc", "xyz" }, case.name .. " should leave the older edit independently undoable")
          assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 0 }, case.name .. " should not claim the older edit selection")
        end)
      end
    end,
  },
  {
    name = "newline edits preserve multicursors and form one undo unit",
    run = function()
      reset_case({ "a", "b", "c" })
      helix.select_whole_buffer()
      helix.select_regex_matches("a|c")
      helix.add_newline_relative(1)
      assert_equal(current_lines(), { "a", "", "b", "c", "" }, "newline below should edit every selection")
      assert_equal(selection_texts(), { "a", "c" }, "newline below should preserve selections through shifted rows")

      helix.undo()
      assert_equal(current_lines(), { "a", "b", "c" }, "one undo should remove every newline from the command")
      assert_equal(selection_texts(), { "a", "c" }, "newline undo should restore the original multicursors")
      helix.redo()
      assert_equal(current_lines(), { "a", "", "b", "c", "" }, "one redo should restore every inserted newline")
      assert_equal(selection_texts(), { "a", "c" }, "newline redo should restore the remapped multicursors")
    end,
  },
  {
    name = "open line keeps its newline and inserted text in one undo unit",
    run = function()
      reset_case({ "abc" }, 1, 1)
      helix.open_line_above()
      vim.wait(50)
      vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { "up" })
      vim.cmd("stopinsert")
      vim.wait(100)
      assert_equal(current_lines(), { "up", "abc" }, "open line should insert text on its new line")

      helix.undo()
      assert_equal(current_lines(), { "abc" }, "one undo should remove both the inserted text and its new line")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 1 }, "open line undo should restore its original cursor")

      helix.redo()
      assert_equal(current_lines(), { "up", "abc" }, "one redo should restore both the new line and its text")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 1 }, "open line redo should restore its insertion endpoint")
    end,
  },
  {
    name = "jumplist selections survive edits undo and redo",
    run = function()
      with_fresh_tab(function()
        reset_case({ "first", "beta" }, 2, 0)
        helix.toggle_select_mode()
        for _ = 1, 3 do
          helix.normal_motion("l")()
        end
        helix.save_selection_to_jumplist()
        vim.api.nvim_buf_set_lines(0, 0, 0, false, { "inserted" })
        vim.cmd("undo")
        vim.cmd("redo")
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        helix.jump_backward()
        assert_equal(selection_texts(), { "beta" }, "the saved selection should remain valid through undo and redo")
        assert_equal(helix.primary_selection_entry().cursor_pos[1], 3, "the jump should track the inserted line")
      end)
    end,
  },
  {
    name = "jumplist selections created inside an undone edit remain valid",
    run = function()
      with_fresh_tab(function()
        reset_case({ "" })
        vim.api.nvim_buf_set_lines(0, 0, 0, false, { "", "" })
        vim.api.nvim_win_set_cursor(0, { 3, 0 })
        helix.save_selection_to_jumplist()
        vim.cmd("undo")
        helix.jump_backward()
        helix.jump_forward()
        assert_equal(current_lines(), { "" }, "jumplist navigation should not resurrect an undone insertion")
        assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "the saved point should clamp through the undone edit")
      end)
    end,
  },
  {
    name = "counted earlier and later navigation crosses multiple edits and clamps safely",
    run = function()
      reset_case({ "Ab" })
      helix.select_whole_buffer()
      helix.set_selection_case("upper")
      helix.set_selection_case("lower")
      assert_equal(current_lines(), { "ab" }, "two history-producing edits should apply")
      helix.undo()
      assert_equal(current_lines(), { "AB" }, "one undo should reverse only the most recent API-based edit")
      helix.redo()
      assert_equal(current_lines(), { "ab" }, "redo should reapply only the most recent API-based edit")
      helix.earlier(2)
      assert_equal(current_lines(), { "Ab" }, "counted earlier should cross two changes")
      helix.later(2)
      assert_equal(current_lines(), { "ab" }, "counted later should cross two changes")
      helix.later(99)
      assert_equal(current_lines(), { "ab" }, "an excessive later count should be a no-op")
    end,
  },
  {
    name = "jumplist navigation restores complete cross-buffer selection state",
    run = function()
      with_fresh_tab(function()
        reset_case({ "alpha beta" })
        local first = vim.api.nvim_get_current_buf()
        helix.select_whole_buffer()
        helix.select_regex_matches("alpha|beta")
        helix.flip_selection_direction()
        helix.save_selection_to_jumplist()

        local second = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_lines(second, 0, -1, false, { "destination" })
        vim.api.nvim_set_current_buf(second)
        helix.jump_backward()
        assert_equal(vim.api.nvim_get_current_buf(), first, "C-o should restore the source buffer")
        assert_equal(selection_texts(), { "alpha", "beta" }, "C-o should restore every selection")
        for _, entry in ipairs(helix.current_selection_entries()) do
          assert(entry.anchor_pos[2] > entry.cursor_pos[2], "C-o should restore selection direction")
        end
        helix.jump_forward()
        assert_equal(vim.api.nvim_get_current_buf(), second, "C-i should restore the live destination buffer")
      end)
    end,
  },
  {
    name = "split views retain independent selections while sharing edits",
    run = function()
      with_fresh_tab(function()
        reset_case({ "alpha beta" })
        helix.select_whole_buffer()
        helix.select_regex_matches("alpha")
        local source = vim.api.nvim_get_current_win()
        helix.split_current_view("horizontal")
        local target = vim.api.nvim_get_current_win()
        helix.select_whole_buffer()
        helix.select_regex_matches("beta")
        vim.api.nvim_set_current_win(source)
        assert_equal(selection_texts(), { "alpha" }, "the source selection should remain independent")
        vim.api.nvim_set_current_win(target)
        vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { "prefix " })
        vim.api.nvim_set_current_win(source)
        assert_equal(selection_texts(), { "alpha" }, "an inactive view selection should follow shared-buffer edits")
        vim.api.nvim_win_close(target, true)
        assert_equal(selection_texts(), { "alpha" }, "closing the other view should restore the source cleanly")
      end)
    end,
  },
  {
    name = "inactive split selections survive delete undo redo and a history branch",
    run = function()
      with_fresh_tab(function()
        reset_case({ "one", "two", "three" }, 3, 0)
        helix.select_whole_buffer()
        helix.select_regex_matches("three")
        local source = vim.api.nvim_get_current_win()
        helix.split_current_view("horizontal")
        local target = vim.api.nvim_get_current_win()

        vim.api.nvim_set_current_win(source)
        vim.api.nvim_buf_set_lines(0, 0, 1, false, {})
        vim.api.nvim_set_current_win(target)
        assert_equal(helix.primary_selection_entry().cursor_pos[1], 2, "the inactive split should track a deletion")
        assert_equal(selection_texts(), { "three" }, "the deleted-prefix edit should preserve selection text")

        vim.api.nvim_set_current_win(source)
        vim.cmd("undo")
        vim.api.nvim_set_current_win(target)
        assert_equal(helix.primary_selection_entry().cursor_pos[1], 3, "the inactive split should track undo")

        vim.api.nvim_set_current_win(source)
        vim.cmd("redo")
        vim.api.nvim_set_current_win(target)
        assert_equal(helix.primary_selection_entry().cursor_pos[1], 2, "the inactive split should track redo")

        vim.api.nvim_set_current_win(source)
        vim.cmd("undo")
        vim.api.nvim_buf_set_lines(0, 0, 0, false, { "zero", "zero again" })
        vim.api.nvim_set_current_win(target)
        assert_equal(helix.primary_selection_entry().cursor_pos[1], 5, "the inactive split should follow a new history branch")
        assert_equal(selection_texts(), { "three" }, "branching should preserve the inactive selection")

        vim.api.nvim_win_close(source, true)
        helix.delete()
        assert_equal(current_lines(), { "zero", "zero again", "one", "two", "" }, "the surviving split selection should remain editable")
      end)
    end,
  },
  {
    name = "picker ranges handle Unicode multiline EOF and clamping",
    run = function()
      reset_case({ "aé中z", "尾x" })
      helix.select_picker_location({ lnum = 1, col = 2, end_lnum = 1, end_col = 7 })
      assert_equal(selection_texts(), { "é中" }, "picker byte columns should select Unicode ranges")
      helix.select_picker_location({ lnum = 1, col = 2, end_lnum = 2, end_col = 4 })
      assert_equal(selection_texts(), { "é中z\n尾" }, "picker ranges should preserve exclusive multiline ends")
      helix.select_picker_location({ lnum = 99, col = 99, end_lnum = 99, end_col = 99 })
      assert_equal(helix.primary_selection_entry().cursor_pos, { 2, 3 }, "out-of-range locations should clamp to EOF")
      assert_equal(selection_texts(), { "" }, "an explicit empty range should remain semantically empty")
      assert_equal(helix.primary_selection_entry().empty, true, "an empty picker range should retain its empty marker")
    end,
  },
  {
    name = "LSP jumps checkpoint invocation time and no-result requests do not push",
    run = function()
      with_fresh_tab(function()
        reset_case({ "origin", "moved", "destination" })
        local original = vim.lsp.buf.definition
        local request_opts
        vim.lsp.buf.definition = function(opts)
          request_opts = opts
        end
        local ok, err = xpcall(function()
          pickers.definitions_picker()
          vim.api.nvim_win_set_cursor(0, { 2, 0 })
          request_opts.on_list({
            title = "definitions",
            items = {
              {
                bufnr = vim.api.nvim_get_current_buf(),
                filename = vim.api.nvim_buf_get_name(0),
                lnum = 3,
                col = 1,
                text = "destination",
              },
            },
          })
          helix.jump_backward()
          assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "C-o should return to where gd was invoked")

          local before = #helix.jumplist_items()
          pickers.definitions_picker()
          request_opts.on_list({ title = "definitions", items = {} })
          assert_equal(#helix.jumplist_items(), before, "an empty LSP result should not add a jump")
        end, debug.traceback)
        vim.lsp.buf.definition = original
        if not ok then
          error(err)
        end
      end)
    end,
  },
  {
    name = "multiple LSP results commit only when a picker action selects a range",
    run = function()
      with_fresh_tab(function()
        reset_case({ "origin", "first", "second" })
        local telescope_pickers = require("telescope.pickers")
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local original_new = telescope_pickers.new
        local original_definition = vim.lsp.buf.definition
        local original_selected = action_state.get_selected_entry
        local request_opts
        local picker_spec
        telescope_pickers.new = function(_, spec)
          picker_spec = spec
          return { find = function() end }
        end
        vim.lsp.buf.definition = function(opts)
          request_opts = opts
        end
        actions._clear()

        local ok, err = xpcall(function()
          local before = #helix.jumplist_items()
          pickers.definitions_picker()
          request_opts.on_list({
            title = "definitions",
            items = {
              { bufnr = vim.api.nvim_get_current_buf(), lnum = 2, col = 1, end_lnum = 2, end_col = 6, text = "first" },
              { bufnr = vim.api.nvim_get_current_buf(), lnum = 3, col = 1, end_lnum = 3, end_col = 7, text = "second" },
            },
          })
          assert(picker_spec and picker_spec.attach_mappings, "multiple locations should open a picker")
          picker_spec.attach_mappings(0, function() end)
          assert_equal(#helix.jumplist_items(), before, "opening or cancelling the picker should not commit a jump")

          action_state.get_selected_entry = function()
            return {
              value = {
                bufnr = vim.api.nvim_get_current_buf(),
                lnum = 3,
                col = 1,
                end_lnum = 3,
                end_col = 7,
              },
            }
          end
          local action = actions.select_default
          action._pre[action[1]]()
          action._post[action[1]]()
          assert_equal(#helix.jumplist_items(), before + 1, "selecting a result should commit one jump")
          assert_equal(selection_texts(), { "second" }, "the selected LSP range should be restored in the destination")
        end, debug.traceback)

        telescope_pickers.new = original_new
        vim.lsp.buf.definition = original_definition
        action_state.get_selected_entry = original_selected
        actions._clear()
        if not ok then
          error(err)
        end
      end)
    end,
  },
  {
    name = "directory traversal delays its jumplist commit until a file opens",
    run = function()
      local root = vim.fn.tempname()
      local subdir = vim.fs.joinpath(root, "sub")
      local target_file = vim.fs.joinpath(subdir, "target.txt")
      vim.fn.mkdir(subdir, "p")
      vim.fn.writefile({ "target" }, target_file)

      local ok, err = xpcall(function()
        with_fresh_tab(function()
          reset_case({ "origin" })
          vim.api.nvim_buf_set_name(0, vim.fs.joinpath(root, "origin.txt"))
          local telescope_pickers = require("telescope.pickers")
          local finders = require("telescope.finders")
          local actions = require("telescope.actions")
          local action_state = require("telescope.actions.state")
          local original_new = telescope_pickers.new
          local original_new_table = finders.new_table
          local original_replace = actions.select_default.replace
          local original_close = actions.close
          local original_selected = action_state.get_selected_entry
          local specs = {}
          local replacement
          local selected

          telescope_pickers.new = function(_, spec)
            specs[#specs + 1] = spec
            return { find = function() end }
          end
          finders.new_table = function(opts)
            return { results = opts.results }
          end
          actions.select_default.replace = function(_, callback)
            replacement = callback
          end
          actions.close = function() end
          action_state.get_selected_entry = function()
            return selected
          end

          local inner_ok, inner_err = xpcall(function()
            local before = #helix.jumplist_items()
            pickers.open_buffer_directory_explorer()
            specs[1].attach_mappings(1)
            local directory
            for _, entry in ipairs(specs[1].finder.results) do
              if entry.is_dir and not entry.is_parent then
                directory = entry
                break
              end
            end
            assert(directory, "the explorer should list the child directory")
            selected = { value = directory }
            replacement()
            vim.wait(500, function()
              return #specs == 2
            end, 10)
            assert_equal(#helix.jumplist_items(), before, "entering a directory should not commit a jump")

            specs[2].attach_mappings(2)
            local file
            for _, entry in ipairs(specs[2].finder.results) do
              if not entry.is_dir then
                file = entry
                break
              end
            end
            assert(file, "the nested explorer should list the target file")
            selected = { value = file }
            replacement()
            assert_equal(vim.api.nvim_buf_get_name(0), target_file, "selecting the file should open it")
            assert_equal(#helix.jumplist_items(), before + 1, "opening a file should commit exactly one jump")
          end, debug.traceback)

          telescope_pickers.new = original_new
          finders.new_table = original_new_table
          actions.select_default.replace = original_replace
          actions.close = original_close
          action_state.get_selected_entry = original_selected
          if not inner_ok then
            error(inner_err)
          end
        end)
      end, debug.traceback)
      vim.fn.delete(root, "rf")
      if not ok then
        error(err)
      end
    end,
  },
  {
    name = "the jumplist picker selects the requested historical entry",
    run = function()
      with_fresh_tab(function()
        reset_case({ "first", "second", "live" })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        helix.save_selection_to_jumplist()
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        helix.save_selection_to_jumplist()
        vim.api.nvim_win_set_cursor(0, { 3, 0 })

        local telescope_pickers = require("telescope.pickers")
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local original_new = telescope_pickers.new
        local original_replace = actions.select_default.replace
        local original_close = actions.close
        local original_selected = action_state.get_selected_entry
        local picker_spec
        local replacement

        telescope_pickers.new = function(_, spec)
          picker_spec = spec
          return { find = function() end }
        end
        actions.select_default.replace = function(_, callback)
          replacement = callback
        end
        actions.close = function() end

        local ok, err = xpcall(function()
          pickers.jumplist_picker()
          picker_spec.attach_mappings(1)
          local oldest = helix.jumplist_items()[2]
          action_state.get_selected_entry = function()
            return { value = oldest }
          end
          replacement()
          assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "selecting the oldest item should jump to line one")
        end, debug.traceback)

        telescope_pickers.new = original_new
        actions.select_default.replace = original_replace
        actions.close = original_close
        action_state.get_selected_entry = original_selected
        if not ok then
          error(err)
        end
      end)
    end,
  },
  {
    name = "Tree-sitter sibling and child selection preserves direction and is idempotent",
    run = function()
      reset_case({ "return foo(bar, baz)" }, 1, 11)
      start_treesitter("lua")
      helix.expand_selection()
      helix.flip_selection_direction()
      helix.select_all_treesitter_siblings()
      assert_equal(selection_texts(), { "bar", "baz" }, "all siblings should be selected")
      for _, entry in ipairs(helix.current_selection_entries()) do
        assert(entry.anchor_pos[2] > entry.cursor_pos[2], "sibling direction should be preserved")
      end
      helix.select_all_treesitter_siblings()
      assert_equal(selection_texts(), { "bar", "baz" }, "selecting all siblings twice should be stable")

      reset_case({ "return foo(bar, baz)" }, 1, 16)
      start_treesitter("lua")
      helix.expand_selection()
      helix.select_all_treesitter_siblings()
      assert_equal(selection_texts()[1], "baz", "the originally selected sibling should remain primary")

      reset_case({ "return foo(bar, baz)" }, 1, 7)
      start_treesitter("lua")
      helix.expand_selection()
      while selection_texts()[1] ~= "foo(bar, baz)" do
        local before = selection_texts()[1]
        helix.expand_selection()
        if selection_texts()[1] == before then
          break
        end
      end
      helix.flip_selection_direction()
      helix.select_all_treesitter_children()
      assert_equal(selection_texts(), { "foo", "(bar, baz)" }, "all named children should be selected")
      for _, entry in ipairs(helix.current_selection_entries()) do
        assert(entry.anchor_pos[2] > entry.cursor_pos[2], "child direction should be preserved")
      end
    end,
  },
  {
    name = "Tree-sitter operations handle independent cursors and select-mode parent extension",
    run = function()
      reset_case({ "return foo(1, 2) + bar(3, 4)" })
      start_treesitter("lua")
      helix.select_whole_buffer()
      helix.select_regex_matches("1|3")
      helix.select_all_treesitter_siblings()
      assert_equal(selection_texts(), { "1", "2", "3", "4" }, "each cursor should select siblings independently")

      reset_case({ "return foo(bar)" }, 1, 11)
      start_treesitter("lua")
      helix.toggle_select_mode()
      local anchor = vim.deepcopy(helix.primary_selection_entry().anchor_pos)
      helix.move_parent_node_boundary("end")
      helix.move_parent_node_boundary("end")
      assert_equal(helix.primary_selection_entry().anchor_pos, anchor, "parent boundary motion should retain the select-mode anchor")
      assert(helix.primary_selection_entry().cursor_pos[2] > anchor[2], "parent boundary motion should extend the selection")

      reset_case({ "plain text" })
      helix.select_all_treesitter_children()
      assert_equal(selection_texts(), { "p" }, "syntax commands without a parser should leave the cursor selection unchanged")
    end,
  },
  {
    name = "Tree-sitter child and edge no-ops match the upstream matrix",
    run = function()
      reset_case({ "return foo(1)" }, 1, 12)
      start_treesitter("lua")
      helix.select_whole_buffer()
      helix.select_regex_matches("1")
      local leaf = helix.current_selection_entries()
      helix.select_all_treesitter_children()
      assert_equal(helix.current_selection_entries(), leaf, "a leaf node with no named children should stay unchanged")

      reset_case({ "return foo(1)" })
      start_treesitter("lua")
      helix.select_whole_buffer()
      local root = helix.current_selection_entries()
      helix.select_all_treesitter_siblings()
      assert_equal(helix.current_selection_entries(), root, "a root selection with no siblings should stay unchanged")
    end,
  },
  {
    name = "Tree-sitter children operate independently across multiple parents",
    run = function()
      reset_case({ "local a = {1, 2}; local b = {3, 4}" })
      start_treesitter("lua")
      helix.select_whole_buffer()
      helix.select_regex_matches("[{]1, 2[}]|[{]3, 4[}]")
      helix.select_all_treesitter_children()
      assert_equal(selection_texts(), { "1", "2", "3", "4" }, "each parent should contribute its own named children")
      local once = helix.current_selection_entries()
      helix.select_all_treesitter_children()
      assert_equal(helix.current_selection_entries(), once, "selecting children again at leaf nodes should be idempotent")
    end,
  },
  {
    name = "Tree-sitter conflicting sibling selections normalize overlaps",
    run = function()
      reset_case({ "local a = {1, 2, 3, 4, 5}" })
      start_treesitter("lua")
      helix.select_whole_buffer()
      helix.select_regex_matches("1|3, 4")
      helix.select_all_treesitter_siblings()
      local entries = helix.current_selection_entries()
      for left_index = 1, #entries do
        for right_index = left_index + 1, #entries do
          local left = entries[left_index]
          local right = entries[right_index]
          local disjoint = left.end_pos[1] < right.start_pos[1]
            or right.end_pos[1] < left.start_pos[1]
            or (left.end_pos[1] == right.start_pos[1] and left.end_pos[2] < right.start_pos[2])
            or (right.end_pos[1] == left.start_pos[1] and right.end_pos[2] < left.start_pos[2])
          assert(disjoint, "conflicting Tree-sitter results should be normalized into disjoint selections")
        end
      end
      assert(#entries < 6, "the wider conflicting selection should subsume redundant list-item ranges")
    end,
  },
  {
    name = "full-page scrolling and wrapped-line movement work in both directions",
    run = function()
      local lines = {}
      for row = 1, 100 do
        lines[row] = ("line %03d %s"):format(row, string.rep("x", 120))
      end
      reset_case(lines, 50, 8)
      local amount = math.max(vim.api.nvim_win_get_height(0) - 2, 1)
      helix.scroll_page(-1)
      assert_equal(vim.api.nvim_win_get_cursor(0)[1], 50 - amount, "page up should move by a viewport")
      helix.scroll_page(1)
      assert_equal(vim.api.nvim_win_get_cursor(0)[1], 50, "page down should reverse page up")

      reset_case(lines, 50, 8)
      helix.scroll_page(-1, 2)
      assert_equal(vim.api.nvim_win_get_cursor(0)[1], 50 - (2 * amount), "counted page up should multiply the viewport distance")

      reset_case(lines, 30, 8)
      helix.copy_selection_on_adjacent_line(1)
      helix.scroll_half_page(1, 5)
      local rows = {}
      for _, entry in ipairs(helix.current_selection_entries()) do
        rows[#rows + 1] = entry.cursor_pos[1]
      end
      table.sort(rows)
      assert_equal(rows, { 35, 36 }, "scrolling should move every cursor while retaining their separation")

      reset_case(lines, 40, 8)
      helix.toggle_select_mode()
      local anchor = vim.deepcopy(helix.primary_selection_entry().anchor_pos)
      helix.scroll_half_page(1, 5)
      assert_equal(helix.primary_selection_entry().anchor_pos, anchor, "scrolling in select mode should preserve its anchor")
      assert_equal(helix.primary_selection_entry().cursor_pos[1], 45, "scrolling in select mode should extend the cursor")

      reset_case({ string.rep("x", 240), "next" }, 1, 160)
      vim.wo.wrap = true
      local before = vim.api.nvim_win_get_cursor(0)[2]
      helix.move_visual_line_up()
      assert_equal(vim.api.nvim_win_get_cursor(0)[1], 1, "visual-line up should stay on the wrapped row")
      assert(vim.api.nvim_win_get_cursor(0)[2] < before, "visual-line up should move to the previous screen row")
      vim.wo.wrap = false
    end,
  },
  {
    name = "scrolling clamps at bounds and restores preferred visual columns",
    run = function()
      reset_case({ "first", "middle", "last" }, 1, 0)
      helix.scroll_page(-1, 99)
      assert_equal(vim.api.nvim_win_get_cursor(0)[1], 1, "page up should clamp at the first line")
      helix.scroll_page(1, 99)
      assert_equal(vim.api.nvim_win_get_cursor(0)[1], 3, "page down should clamp at the final line")

      reset_case({ "パーティーへ行かないか", "x", "abcdefghijk" })
      for _ = 1, 4 do
        helix.normal_motion("l")()
      end
      helix.toggle_select_mode()
      helix.scroll_half_page(1, 1)
      assert_equal(helix.primary_selection_entry().cursor_pos, { 2, 2 }, "scrolling should clamp on a short line")
      helix.scroll_half_page(1, 1)
      assert_equal(helix.primary_selection_entry().cursor_pos, { 3, 9 }, "scrolling should restore the wide-text visual column")
    end,
  },
  {
    name = "window operations preserve buffers layouts and scratch properties",
    run = function()
      with_fresh_tab(function()
        reset_case({ "left" })
        local left_buffer = vim.api.nvim_get_current_buf()
        vim.cmd("botright vnew")
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "right" })
        local right_buffer = vim.api.nvim_get_current_buf()
        local right_win = vim.api.nvim_get_current_win()
        assert_equal(vim.fn.winlayout()[1], "row", "the setup should be vertical")
        helix.swap_with_window("h")
        assert_equal(vim.api.nvim_get_current_buf(), right_buffer, "swap should carry the current buffer into the adjacent window")
        assert_equal(vim.api.nvim_win_get_buf(right_win), left_buffer, "the old right window should receive the left buffer")
        helix.transpose_splits()
        assert_equal(vim.fn.winlayout()[1], "col", "transpose should make a horizontal layout")
        helix.transpose_splits()
        assert(vim.tbl_contains(vim.api.nvim_list_bufs(), right_buffer), "the other buffer should remain valid")

        local tab_count = #vim.api.nvim_list_tabpages()
        helix.toggle_focus_window()
        assert_equal(#vim.api.nvim_list_tabpages(), tab_count + 1, "focus should open a temporary tab")
        helix.toggle_focus_window()
        assert_equal(#vim.api.nvim_list_tabpages(), tab_count, "focus should return to the split tab")

        helix.new_scratch_split("horizontal")
        assert_equal(vim.b.helix_scratch_split, true, "scratch splits should be marked")
        assert_equal(vim.bo.bufhidden, "wipe", "scratch splits should wipe on close")
        assert_equal(vim.bo.swapfile, false, "scratch splits should not create swapfiles")
      end)
    end,
  },
  {
    name = "vertical scratch splits and window-position motions are exercised",
    run = function()
      with_fresh_tab(function()
        local lines = {}
        for row = 1, 80 do
          lines[row] = "line " .. row
        end
        reset_case(lines, 40, 0)
        helix.goto_window_position("H")
        local top_row = vim.api.nvim_win_get_cursor(0)[1]
        helix.goto_window_position("L")
        assert(vim.api.nvim_win_get_cursor(0)[1] > top_row, "window bottom should be below window top")
        helix.goto_window_position("M")
        local middle_row = vim.api.nvim_win_get_cursor(0)[1]
        assert(middle_row > top_row, "window middle should be below window top")

        local count = #vim.api.nvim_tabpage_list_wins(0)
        helix.new_scratch_split("vertical")
        assert_equal(#vim.api.nvim_tabpage_list_wins(0), count + 1, "vertical scratch should add a window")
        assert_equal(vim.b.helix_scratch_split, true, "vertical scratch should use scratch settings")
      end)
    end,
  },
  {
    name = "joins cover empty lines trailing spaces and changing comment tokens",
    run = function()
      reset_case({ "a", "", "b", "", "c", "", "d", "", "e" })
      helix.select_whole_buffer()
      helix.join_selections(true)
      assert_equal(current_lines(), { "a b c d e" }, "Alt-J should collapse intervening empty lines")
      assert_equal(selection_texts(), { " ", " ", " ", " " }, "Alt-J should select every inserted separator")

      reset_case({ "aaa   ", "", "bb  ", "", "c " })
      helix.select_whole_buffer()
      helix.join_selections(true)
      assert_equal(current_lines(), { "aaa    bb   c " }, "Alt-J should retain trailing whitespace")

      reset_case({ " // a", "// b", "/// c", "/// d", "e", "/// f", "// g" })
      vim.bo.commentstring = "// %s"
      vim.bo.comments = ":///,://"
      helix.select_whole_buffer()
      helix.join_selections(false)
      assert_equal(current_lines(), { " // a b /// c d e f // g" }, "J should strip only comment tokens matching the prior line")

      reset_case({ "abc", "", "    def" })
      helix.join_selections(false)
      helix.join_selections(false)
      assert_equal(current_lines(), { "abc def" }, "repeated J should skip an empty line and trim indentation")

      reset_case({ "abc", "", "def" })
      helix.join_selections(true)
      assert_equal(current_lines(), { "abc", "def" }, "Alt-J on an adjacent empty line should remove only that line")
      assert_equal(selection_texts(), { "a" }, "Alt-J should leave the original cell selected when no separator is inserted")
    end,
  },
}

for _, case in ipairs(cases) do
  local ok, err = xpcall(case.run, debug.traceback)
  if not ok then
    error(case.name .. "\n" .. err)
  end
end

print("parity-tests-ok")
