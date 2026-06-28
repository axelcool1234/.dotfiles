local position = require("axelcool1234.helix.position")

local M = {}

local function deepcopy_or_empty(value)
  return vim.deepcopy(value or {})
end

local function positions_equal(left, right)
  return left[1] == right[1] and left[2] == right[2]
end

local function entries_equal(left, right)
  return positions_equal(left.anchor_pos, right.anchor_pos)
    and positions_equal(left.cursor_pos, right.cursor_pos)
end

local function snapshots_equal(left, right)
  if not left or not right then
    return false
  end

  local left_cursor_positions = left.cursor_positions or {}
  local right_cursor_positions = right.cursor_positions or {}
  local left_preferred_columns = left.preferred_columns or {}
  local right_preferred_columns = right.preferred_columns or {}

  if left.buffer ~= right.buffer
    or left.extend_mode ~= right.extend_mode
    or left.had_preview ~= right.had_preview
    or #left.entries ~= #right.entries
    or #left_cursor_positions ~= #right_cursor_positions
    or #left_preferred_columns ~= #right_preferred_columns then
    return false
  end

  for index, entry in ipairs(left.entries) do
    if not entries_equal(entry, right.entries[index]) then
      return false
    end
  end

  for index, cursor_pos in ipairs(left_cursor_positions) do
    if not positions_equal(cursor_pos, right_cursor_positions[index]) then
      return false
    end
  end

  for index, preferred in ipairs(left_preferred_columns) do
    if preferred ~= right_preferred_columns[index] then
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

  local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-jumplist")
  local views = {}

  local jumplist = {}

  local function view_for(win)
    local view = views[win]
    if view then
      return view
    end

    view = {
      jumps = {},
      current = 1,
    }
    views[win] = view
    return view
  end

  local function extmark_pos_1indexed(buffer, mark_id)
    local pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark_id, {})
    if #pos == 0 then
      return nil
    end

    local row = pos[1] + 1
    return { row, position.char_col_from_byte_col0(position.line_text(buffer, row), pos[2]) }
  end

  local function create_mark(buffer, pos)
    local row, col = position.before_boundary(buffer, pos)
    return vim.api.nvim_buf_set_extmark(buffer, namespace, row, col, {
      right_gravity = false,
      strict = false,
    })
  end

  local function create_jump(snapshot, reason)
    local jump = {
      buffer = snapshot.buffer,
      entries = {},
      cursor_positions = {},
      preferred_columns = deepcopy_or_empty(snapshot.preferred_columns),
      extend_mode = snapshot.extend_mode == true,
      had_preview = snapshot.had_preview == true,
      reason = reason,
    }

    for index, entry in ipairs(snapshot.entries) do
      jump.entries[index] = {
        anchor_id = create_mark(snapshot.buffer, entry.anchor_pos),
        cursor_id = create_mark(snapshot.buffer, entry.cursor_pos),
      }
    end

    for index, cursor_pos in ipairs(snapshot.cursor_positions or {}) do
      jump.cursor_positions[index] = create_mark(snapshot.buffer, cursor_pos)
    end

    return jump
  end

  local function cleanup_jump(jump)
    if not jump or not jump.buffer or not vim.api.nvim_buf_is_valid(jump.buffer) then
      return
    end

    for _, entry in ipairs(jump.entries or {}) do
      pcall(vim.api.nvim_buf_del_extmark, jump.buffer, namespace, entry.anchor_id)
      pcall(vim.api.nvim_buf_del_extmark, jump.buffer, namespace, entry.cursor_id)
    end

    for _, mark_id in ipairs(jump.cursor_positions or {}) do
      pcall(vim.api.nvim_buf_del_extmark, jump.buffer, namespace, mark_id)
    end
  end

  local function resolve_snapshot(jump)
    if not jump or not jump.buffer or not vim.api.nvim_buf_is_valid(jump.buffer) then
      return nil
    end

    local snapshot = {
      buffer = jump.buffer,
      entries = {},
      cursor_positions = {},
      preferred_columns = deepcopy_or_empty(jump.preferred_columns),
      extend_mode = jump.extend_mode == true,
      had_preview = jump.had_preview == true,
    }

    for index, entry_marks in ipairs(jump.entries or {}) do
      local anchor_pos = extmark_pos_1indexed(jump.buffer, entry_marks.anchor_id)
      local cursor_pos = extmark_pos_1indexed(jump.buffer, entry_marks.cursor_id)
      if not anchor_pos or not cursor_pos then
        return nil
      end

      snapshot.entries[index] = {
        anchor_pos = anchor_pos,
        cursor_pos = cursor_pos,
      }
    end

    for index, entry in ipairs(snapshot.entries) do
      entry.start_pos = entry.anchor_pos
      entry.end_pos = entry.cursor_pos
      if entry.anchor_pos[1] > entry.cursor_pos[1]
        or (entry.anchor_pos[1] == entry.cursor_pos[1] and entry.anchor_pos[2] > entry.cursor_pos[2]) then
        entry.start_pos = entry.cursor_pos
        entry.end_pos = entry.anchor_pos
      end

      local cursor_mark_id = jump.cursor_positions[index]
      snapshot.cursor_positions[index] = cursor_mark_id and extmark_pos_1indexed(jump.buffer, cursor_mark_id) or entry.cursor_pos
      if not snapshot.cursor_positions[index] then
        return nil
      end

      if snapshot.preferred_columns[index] == nil then
        snapshot.preferred_columns[index] = snapshot.cursor_positions[index][2]
      end
    end

    if #snapshot.cursor_positions == 0 then
      for _, entry in ipairs(snapshot.entries) do
        snapshot.cursor_positions[#snapshot.cursor_positions + 1] = vim.deepcopy(entry.cursor_pos)
      end
    end

    snapshot.cursor_pos = snapshot.cursor_positions[1] or (snapshot.entries[1] and vim.deepcopy(snapshot.entries[1].cursor_pos))

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

    if view.current < 1 then
      view.current = 1
    end
    if view.current > (#view.jumps + 1) then
      view.current = #view.jumps + 1
    end
  end

  local function prune(view)
    while #view.jumps > snapshot_limit do
      cleanup_jump(view.jumps[1])
      table.remove(view.jumps, 1)
      if view.current > 1 then
        view.current = view.current - 1
      end
    end
  end

  local function push_snapshot_to_view(view, snapshot, reason)
    cleanup_invalid_entries(view)

    for index = #view.jumps, view.current, -1 do
      cleanup_jump(view.jumps[index])
      table.remove(view.jumps, index)
    end

    local previous = resolve_snapshot(view.jumps[#view.jumps])
    if previous and snapshots_equal(previous, snapshot) then
      view.current = #view.jumps + 1
      return false
    end

    view.jumps[#view.jumps + 1] = create_jump(snapshot, reason)
    view.current = #view.jumps + 1
    prune(view)
    return true
  end

  function jumplist.push_snapshot(snapshot, reason, win)
    if not snapshot or not snapshot.buffer or not vim.api.nvim_buf_is_valid(snapshot.buffer) then
      return false
    end

    snapshot.cursor_positions = deepcopy_or_empty(snapshot.cursor_positions)
    if #snapshot.cursor_positions == 0 then
      for _, entry in ipairs(snapshot.entries or {}) do
        snapshot.cursor_positions[#snapshot.cursor_positions + 1] = vim.deepcopy(entry.cursor_pos)
      end
    end

    snapshot.preferred_columns = deepcopy_or_empty(snapshot.preferred_columns)
    if #snapshot.preferred_columns == 0 then
      for _, cursor_pos in ipairs(snapshot.cursor_positions) do
        snapshot.preferred_columns[#snapshot.preferred_columns + 1] = cursor_pos[2]
      end
    end

    return push_snapshot_to_view(view_for(win or current_win()), snapshot, reason)
  end

  function jumplist.push_current(reason)
    return jumplist.push_snapshot(capture(), reason)
  end

  function jumplist.jump_backward(count)
    local view = view_for(current_win())
    cleanup_invalid_entries(view)

    local steps = count or 1
    local live_snapshot = capture()
    if view.current == (#view.jumps + 1) then
      push_snapshot_to_view(view, live_snapshot, "live")
    end

    local target = view.current - steps
    if target < 1 then
      return false
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

    if view.current == (#view.jumps + 1) then
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
        local cursor_pos = snapshot.cursor_positions[1] or (snapshot.entries[1] and snapshot.entries[1].cursor_pos)
        local line = cursor_pos and position.line_text(snapshot.buffer, cursor_pos[1]) or ""
        local label = vim.trim(line)
        if label == "" then
          label = "<blank line>"
        end

        local name = vim.api.nvim_buf_get_name(snapshot.buffer)
        if name == "" then
          name = "[No Name]"
        else
          name = vim.fn.fnamemodify(name, ":~:.")
        end

        items[#items + 1] = {
          index = index,
          buffer = snapshot.buffer,
          filename = name,
          cursor_pos = cursor_pos,
          line = label,
          is_current = view.current == index,
          selection_count = #snapshot.entries,
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

      if view.current > (#view.jumps + 1) then
        view.current = #view.jumps + 1
      end
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

  return jumplist
end

return M
