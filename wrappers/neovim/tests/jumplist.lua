local jumplist_module = require("axelcool1234.helix.jumplist")
local state_module = require("axelcool1234.helix.state")

local function assert_equal(actual, expected, label)
  if not vim.deep_equal(actual, expected) then
    error(label .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual))
  end
end

local function fresh_buffer(lines)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  return vim.api.nvim_get_current_buf()
end

local function snapshot(buffer, row, entries)
  entries = entries or { state_module.selection_entry({ row, 1 }, { row, 1 }) }
  local cursor_positions = {}
  local preferred_columns = {}
  for index, entry in ipairs(entries) do
    cursor_positions[index] = vim.deepcopy(entry.cursor_pos)
    preferred_columns[index] = entry.cursor_pos[2]
  end
  return {
    buffer = buffer,
    entries = entries,
    cursor_positions = cursor_positions,
    preferred_columns = preferred_columns,
    had_preview = #entries > 1,
  }
end

local function new_jumplist(buffer, opts)
  opts = opts or {}
  local live = snapshot(buffer, 1)
  local restored
  local current_win = opts.current_win or vim.api.nvim_get_current_win
  local jumplist = jumplist_module.new({
    snapshot_limit = opts.snapshot_limit,
    current_win = current_win,
    capture = function()
      return vim.deepcopy(live)
    end,
    restore = function(value)
      restored = vim.deepcopy(value)
    end,
  })
  return jumplist, function(value)
    live = value
  end, function()
    return restored
  end
end

local cases = {
  {
    name = "counted backward and forward jumps count from the live location",
    run = function()
      local buffer = fresh_buffer({ "a", "b", "c" })
      local jumplist, set_live, restored = new_jumplist(buffer)
      jumplist.push_snapshot(snapshot(buffer, 1), "A")
      jumplist.push_snapshot(snapshot(buffer, 2), "B")
      set_live(snapshot(buffer, 3))

      assert_equal(jumplist.jump_backward(2), true, "two backward jumps should succeed")
      assert_equal(restored().cursor_pos, { 1, 1 }, "two backward jumps should reach A")
      assert_equal(jumplist.jump_forward(2), true, "two forward jumps should return to the live location")
      assert_equal(restored().cursor_pos, { 3, 1 }, "two forward jumps should reach C")
    end,
  },
  {
    name = "out of bounds backward jumps do not synthesize a live entry",
    run = function()
      local buffer = fresh_buffer({ "a", "b", "c" })
      local jumplist, set_live = new_jumplist(buffer)
      jumplist.push_snapshot(snapshot(buffer, 1), "A")
      jumplist.push_snapshot(snapshot(buffer, 2), "B")
      set_live(snapshot(buffer, 3))
      assert_equal(jumplist.jump_backward(99), false, "an excessive count should fail")
      assert_equal(#jumplist.items(), 2, "a failed jump should leave the list unchanged")
    end,
  },
  {
    name = "duplicates are removed and a new branch truncates forward history",
    run = function()
      local buffer = fresh_buffer({ "a", "b", "c", "d" })
      local jumplist, set_live = new_jumplist(buffer)
      assert_equal(jumplist.push_snapshot(snapshot(buffer, 1), "A"), true, "first snapshot should be stored")
      assert_equal(jumplist.push_snapshot(snapshot(buffer, 1), "duplicate"), false, "duplicates should be ignored")
      jumplist.push_snapshot(snapshot(buffer, 2), "B")
      set_live(snapshot(buffer, 3))
      jumplist.jump_backward(1)
      jumplist.push_snapshot(snapshot(buffer, 2), "branch")
      assert_equal(jumplist.jump_forward(1), false, "pushing after a backward jump should truncate the old future")
      assert_equal(#jumplist.items(), 2, "the new branch should retain only A and the branch point")
    end,
  },
  {
    name = "snapshot limits prune the oldest entries",
    run = function()
      local buffer = fresh_buffer({ "a", "b", "c" })
      local jumplist = new_jumplist(buffer, { snapshot_limit = 2 })
      jumplist.push_snapshot(snapshot(buffer, 1), "A")
      jumplist.push_snapshot(snapshot(buffer, 2), "B")
      jumplist.push_snapshot(snapshot(buffer, 3), "C")
      local items = jumplist.items()
      assert_equal(#items, 2, "only two snapshots should remain")
      assert_equal({ items[1].reason, items[2].reason }, { "C", "B" }, "the oldest snapshot should be pruned")
    end,
  },
  {
    name = "extmarks track edits and invalid buffers are cleaned",
    run = function()
      local buffer = fresh_buffer({ "a", "b" })
      local jumplist = new_jumplist(buffer)
      jumplist.push_snapshot(snapshot(buffer, 2), "tracked")
      vim.api.nvim_buf_set_lines(buffer, 0, 0, false, { "inserted" })
      assert_equal(jumplist.items()[1].cursor_pos, { 3, 1 }, "a jump should follow an insertion before it")
      vim.api.nvim_buf_delete(buffer, { force = true })
      assert_equal(#jumplist.items(), 0, "entries for invalid buffers should disappear")
    end,
  },
  {
    name = "views are isolated and cloning preserves navigation position",
    run = function()
      local buffer = fresh_buffer({ "a", "b", "c" })
      local active_view = 1
      local jumplist, set_live, restored = new_jumplist(buffer, {
        current_win = function()
          return active_view
        end,
      })
      jumplist.push_snapshot(snapshot(buffer, 1), "A")
      jumplist.push_snapshot(snapshot(buffer, 2), "B")
      set_live(snapshot(buffer, 3))
      jumplist.jump_backward(1)
      assert_equal(jumplist.clone_view(1, 2), true, "a populated view should clone")

      active_view = 2
      assert_equal(jumplist.jump_backward(1), true, "the clone should preserve the source's current position")
      assert_equal(restored().cursor_pos, { 1, 1 }, "the cloned view should navigate independently to A")
      active_view = 1
      assert_equal(#jumplist.items(), 3, "navigating the clone should not mutate the source view")
      jumplist.remove_view(2)
      active_view = 2
      assert_equal(#jumplist.items(), 0, "removing a view should clear its list")
    end,
  },
}

for _, case in ipairs(cases) do
  local ok, err = xpcall(case.run, debug.traceback)
  if not ok then
    error(case.name .. "\n" .. err)
  end
end

print("jumplist-tests-ok")
