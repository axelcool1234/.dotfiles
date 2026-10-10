local position = require("axelcool1234.helix.position")
local range_module = require("axelcool1234.helix.range")
local selection_module = require("axelcool1234.helix.selection")
local state_module = require("axelcool1234.helix.state")
local transaction_module = require("axelcool1234.helix.transaction")
local integer = require("axelcool1234.helix.integer")
local case = require("axelcool1234.helix.case")

local function assert_equal(actual, expected, label)
  if not vim.deep_equal(actual, expected) then
    error(label .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual))
  end
end

vim.cmd("enew!")
local buffer = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "∀x", "é👍🏽", "👨‍👩‍👧‍👦z", "🇺🇸q" })

assert_equal(integer.increment("0xff", 1), "0x100", "integer transforms should preserve radix semantics")
assert_equal(integer.increment("-001", 2), "001", "integer transforms should preserve signed padding")
assert_equal(case.upper("straße"), "STRASSE", "case transforms should support expanding Unicode mappings")
assert_equal(case.toggle("Éa"), "éA", "case toggling should operate on grapheme clusters")

assert_equal(position.boundary_from_byte(buffer, vim.api.nvim_buf_line_count(buffer), 0), position.boundary(4, 2), "a byte range ending one row past the buffer should map to the EOF boundary")
local whole_buffer = range_module.from_byte_range(buffer, 0, 0, vim.api.nvim_buf_line_count(buffer), 0)
assert_equal(whole_buffer:text(), "∀x\né👍🏽\n👨‍👩‍👧‍👦z\n🇺🇸q", "one-past-buffer byte ranges should retain the complete final line")

local forall = range_module.from_span_cells(buffer, { 1, 1 }, { 1, 1 })
assert_equal({ forall:byte_range() }, { 0, 0, 0, 3 }, "a logical cell should convert to its complete UTF-8 range")
assert_equal(forall:text(), "∀", "the range should select the complete symbol")

for row, expected in pairs({ [2] = "é", [3] = "👨‍👩‍👧‍👦", [4] = "🇺🇸" }) do
  local grapheme = range_module.from_span_cells(buffer, { row, 1 }, { row, 1 })
  assert_equal(grapheme:text(), expected, "one logical cell should select one grapheme cluster")
end

local multiline = range_module.from_span_cells(buffer, { 1, 2 }, { 2, 1 })
assert_equal(multiline:cursor(), { 2, 1 }, "forward ranges should expose the inward head cell")
assert_equal(multiline:anchor_cell(), { 1, 2 }, "forward ranges should preserve the anchor cell")
assert_equal(({ multiline:byte_range() })[1], 0, "half-open ranges should start on the anchor boundary")

local backward = range_module.from_span_cells(buffer, { 2, 2 }, { 1, 2 })
assert_equal(backward:direction(), -1, "backward ranges should retain direction")
assert_equal(backward:cursor(), { 1, 2 }, "backward ranges should expose the head-side cell")

local eof = range_module.from_span_cells(buffer, { 1, 1 }, { 4, 3 })
eof.visual_cursor = { 4, 3 }
local reversed_eof = eof:reversed()
assert_equal(reversed_eof:cursor(), { 1, 1 }, "reversing should move the visible cursor to the former anchor")
assert_equal(reversed_eof:anchor_cell(), { 4, 3 }, "reversing should preserve a synthetic EOF anchor")
local restored_eof = reversed_eof:reversed()
assert_equal(restored_eof:cursor(), { 4, 3 }, "reversing twice should restore a synthetic EOF cursor")
assert_equal(restored_eof:text(), eof:text(), "reversing should not alter the selected text")

local adjacent = selection_module.new(buffer, {
  range_module.from_span_cells(buffer, { 1, 1 }, { 1, 1 }),
  range_module.from_span_cells(buffer, { 1, 2 }, { 1, 2 }),
}, 1)
assert_equal(#adjacent.ranges, 2, "adjacent half-open ranges should not be merged")

local cursor = range_module.cursor_cell(buffer, { 1, 1 })
local insertion = range_module.empty(buffer, position.boundary_before_cell(buffer, { 1, 1 }))
assert_equal(cursor:text(), "∀", "cursor cells should select their complete grapheme")
assert_equal(cursor:is_cursor(), true, "one-cell ranges should render as cursors")
assert_equal(insertion:text(), "", "insertion points should be explicitly empty")
assert_equal(insertion:is_empty(), true, "empty ranges should remain distinct from cursor cells")

local goal = range_module.from_span_cells(buffer, { 2, 2 }, { 2, 2 })
goal.goal_display_col = position.display_col(buffer, goal:cursor())
assert_equal(goal.goal_display_col, 2, "preferred visual columns should live on their range")

local edit = transaction_module.new(buffer)
edit:track_range(forall)
edit:replace(forall, "λ")
local result = edit:apply()
assert_equal(position.line_text(buffer, 1), "λx", "transactions should edit complete Unicode ranges")
assert_equal(result.ranges[1]:text(), "λ", "tracked ranges should map over replacements")

local selected = selection_module.new(buffer, {
  range_module.cursor_cell(buffer, { 1, 1 }),
  range_module.cursor_cell(buffer, { 1, 2 }),
}, 2)
local selection_edit = transaction_module.new(buffer)
selection_edit:track_selection(selected, { affinity = "inside" })
selection_edit:insert(position.boundary(1, 0), "Z")
local selection_result = selection_edit:apply().selection
assert_equal(selection_result.primary_index, 2, "transactions should retain the primary selection")
assert_equal(selection_result:primary():cursor(), { 1, 3 }, "transaction selections should track Unicode edits")

local function tracked_edge_text(affinity)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "∀x" })
  local selected = range_module.from_span_cells(buffer, { 1, 1 }, { 1, 1 })
  local tracker = transaction_module.track_ranges(buffer, { selected }, { affinity = affinity })
  vim.api.nvim_buf_set_text(buffer, 0, 3, 0, 3, { "R" })
  vim.api.nvim_buf_set_text(buffer, 0, 0, 0, 0, { "L" })
  return tracker:resolve()[1]:text()
end

assert_equal(tracked_edge_text("inside"), "∀", "inside affinity should exclude insertions at both edges")
assert_equal(tracked_edge_text("outside"), "L∀R", "outside affinity should include insertions at both edges")
assert_equal(tracked_edge_text("before"), "L∀", "before affinity should keep both endpoints before insertions")
assert_equal(tracked_edge_text("after"), "∀R", "after affinity should keep both endpoints after insertions")

local view_state = state_module.new({ refresh_statusline = function() end })
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "∀x" })
local first_win = vim.api.nvim_get_current_win()
view_state.set_preview_selection(selection_module.single(buffer, range_module.cursor_cell(buffer, { 1, 1 })), { keep_cursor = true })
vim.cmd("vsplit")
local second_win = vim.api.nvim_get_current_win()
view_state.set_preview_selection(selection_module.single(buffer, range_module.cursor_cell(buffer, { 1, 2 })), { keep_cursor = true })

local insert = transaction_module.new(buffer)
insert:insert(position.boundary(1, 0), "Z")
insert:apply()
assert_equal(view_state.selection_for_view(first_win):primary():cursor(), { 1, 2 }, "the first view should track its own selection")
assert_equal(view_state.selection_for_view(second_win):primary():cursor(), { 1, 3 }, "the second view should track its own selection")
vim.cmd("close!")
view_state.forget_view(second_win)
view_state.forget_view(first_win)

print("selection-model-tests-ok")
