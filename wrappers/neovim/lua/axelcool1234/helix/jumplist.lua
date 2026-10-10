local position = require("axelcool1234.helix.position")
local transaction_module = require("axelcool1234.helix.transaction")

local M = {}

local function positions_equal(left, right)
  return left[1] == right[1] and left[2] == right[2]
end

local function entries_equal(left, right)
  return positions_equal(left:anchor_cell(), right:anchor_cell()) and positions_equal(left:cursor(), right:cursor()) and left.goal_display_col == right.goal_display_col and (left:is_empty() == true) == (right:is_empty() == true)
end

local function snapshots_equal(left, right)
  if not left or not right then
    return false
  end
  if left.buffer ~= right.buffer or (left.extend_mode == true) ~= (right.extend_mode == true) or (left.had_preview == true) ~= (right.had_preview == true) or left.selection:len() ~= right.selection:len() or left.selection.primary_index ~= right.selection.primary_index then
    return false
  end
  for index, entry in ipairs(left.selection.ranges) do
    if not right.selection.ranges[index] or not entries_equal(entry, right.selection.ranges[index]) then
      return false
    end
  end
  return true
end

function M.new(opts)
  local capture = assert(opts.capture, "jumplist capture callback is required")
  local restore = assert(opts.restore, "jumplist restore callback is required")
  local snapshot_limit = opts.snapshot_limit or 200
  local current_win = opts.current_win or function()
    return vim.api.nvim_get_current_win()
  end
  local views = {}
  local jumplist = {}

  local function view_for(win)
    local view = views[win]
    if not view then
      view = { jumps = {}, current = 1 }
      views[win] = view
    end
    return view
  end

  local function create_jump(snapshot, reason)
    return {
      buffer = snapshot.buffer,
      tracker = transaction_module.track_selection(snapshot.selection, { affinity = "inside" }),
      extend_mode = snapshot.extend_mode == true,
      had_preview = snapshot.had_preview == true,
      reason = reason,
    }
  end

  local function cleanup_jump(jump)
    if not jump or not jump.buffer or not vim.api.nvim_buf_is_valid(jump.buffer) then
      return
    end
    if jump.tracker then
      jump.tracker:clear()
    end
  end

  local function resolve_snapshot(jump)
    if not jump or not jump.buffer or not vim.api.nvim_buf_is_valid(jump.buffer) then
      return nil
    end
    local selection = jump.tracker:resolve_selection({ keep = true, strict = true })
    if not selection then
      return nil
    end
    local snapshot = {
      buffer = jump.buffer,
      selection = selection,
      extend_mode = jump.extend_mode,
      had_preview = jump.had_preview,
    }
    snapshot.cursor_pos = snapshot.selection:primary():cursor()
    return snapshot
  end

  local function cleanup_invalid_entries(view)
    for index = #view.jumps, 1, -1 do
      if not resolve_snapshot(view.jumps[index]) then
        cleanup_jump(view.jumps[index])
        table.remove(view.jumps, index)
        if index < view.current then
          view.current = view.current - 1
        end
      end
    end
    view.current = math.max(1, math.min(view.current, #view.jumps + 1))
  end

  local function prune(view)
    local removed = 0
    while #view.jumps > snapshot_limit do
      cleanup_jump(view.jumps[1])
      table.remove(view.jumps, 1)
      view.current = math.max(1, view.current - 1)
      removed = removed + 1
    end
    return removed
  end

  local function push_snapshot_to_view(view, snapshot, reason)
    cleanup_invalid_entries(view)
    for index = #view.jumps, view.current, -1 do
      cleanup_jump(view.jumps[index])
      table.remove(view.jumps, index)
    end
    local normalized = vim.tbl_extend("force", snapshot, { selection = snapshot.selection:copy() })
    local previous = resolve_snapshot(view.jumps[#view.jumps])
    if previous and snapshots_equal(previous, normalized) then
      view.current = #view.jumps + 1
      return false, 0
    end
    view.jumps[#view.jumps + 1] = create_jump(normalized, reason)
    view.current = #view.jumps + 1
    return true, prune(view)
  end

  function jumplist.push_snapshot(snapshot, reason, win)
    if not snapshot or not snapshot.buffer or not vim.api.nvim_buf_is_valid(snapshot.buffer) then
      return false
    end
    return push_snapshot_to_view(view_for(win or current_win()), snapshot, reason)
  end

  function jumplist.push_current(reason)
    return jumplist.push_snapshot(capture(), reason)
  end

  function jumplist.jump_backward(count)
    local view = view_for(current_win())
    cleanup_invalid_entries(view)
    local live_snapshot = capture()
    local target = view.current - (count or 1)
    if target < 1 then
      return false
    end
    if view.current == #view.jumps + 1 then
      local _, removed = push_snapshot_to_view(view, live_snapshot, "live")
      target = target - removed
      if target < 1 then
        return false
      end
    end
    local snapshot = resolve_snapshot(view.jumps[target])
    if snapshot and snapshots_equal(live_snapshot, snapshot) then
      target = target - 1
      if target < 1 then
        return false
      end
      snapshot = resolve_snapshot(view.jumps[target])
    end
    if not snapshot then
      return false
    end
    view.current = target
    restore(snapshot)
    return true
  end

  function jumplist.jump_forward(count)
    local view = view_for(current_win())
    cleanup_invalid_entries(view)
    local target = view.current + (count or 1)
    if target > #view.jumps then
      return false
    end
    local snapshot = resolve_snapshot(view.jumps[target])
    if not snapshot then
      return false
    end
    view.current = target
    restore(snapshot)
    return true
  end

  function jumplist.jump_to(index)
    local view = view_for(current_win())
    cleanup_invalid_entries(view)
    if view.current == #view.jumps + 1 then
      push_snapshot_to_view(view, capture(), "live")
    end
    local snapshot = resolve_snapshot(view.jumps[index])
    if not snapshot then
      return false
    end
    view.current = index
    restore(snapshot)
    return true
  end

  function jumplist.items()
    local view = view_for(current_win())
    cleanup_invalid_entries(view)
    local items = {}
    for index = #view.jumps, 1, -1 do
      local snapshot = resolve_snapshot(view.jumps[index])
      if snapshot then
        local cursor_pos = snapshot.cursor_pos
        local line = cursor_pos and position.line_text(snapshot.buffer, cursor_pos[1]) or ""
        local label = vim.trim(line)
        if label == "" then
          label = "<blank line>"
        end
        local name = vim.api.nvim_buf_get_name(snapshot.buffer)
        name = name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":~:.")
        items[#items + 1] = {
          index = index,
          buffer = snapshot.buffer,
          filename = name,
          cursor_pos = cursor_pos,
          line = label,
          is_current = view.current == index,
          selection_count = snapshot.selection:len(),
          reason = view.jumps[index].reason,
        }
      end
    end
    return items
  end

  function jumplist.remove_buffer(buffer)
    for _, view in pairs(views) do
      for index = #view.jumps, 1, -1 do
        local jump = view.jumps[index]
        if jump.buffer == buffer then
          cleanup_jump(jump)
          table.remove(view.jumps, index)
          if index < view.current then
            view.current = view.current - 1
          end
        end
      end
      view.current = math.min(view.current, #view.jumps + 1)
    end
  end

  function jumplist.remove_view(win)
    local view = views[win]
    if not view then
      return
    end
    for _, jump in ipairs(view.jumps) do
      cleanup_jump(jump)
    end
    views[win] = nil
  end

  function jumplist.clone_view(source_win, target_win)
    local source = views[source_win]
    if not source or source_win == target_win then
      return false
    end
    cleanup_invalid_entries(source)
    jumplist.remove_view(target_win)
    local target = view_for(target_win)
    for _, jump in ipairs(source.jumps) do
      local snapshot = resolve_snapshot(jump)
      if snapshot then
        target.jumps[#target.jumps + 1] = create_jump(snapshot, jump.reason)
      end
    end
    target.current = math.min(source.current, #target.jumps + 1)
    return true
  end

  return jumplist
end

return M
