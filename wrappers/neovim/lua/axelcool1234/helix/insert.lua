local M = {}
local position = require("axelcool1234.helix.position")

local function advance_point(start_pos, lines)
  if #lines == 0 then
    return start_pos
  end

  if #lines == 1 then
    return { start_pos[1], start_pos[2] + #lines[1] }
  end

  return { start_pos[1] + #lines - 1, #lines[#lines] + 1 }
end

local function extmark_pos_1indexed(buffer, namespace, mark_id)
  local pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark_id, {})
  if #pos == 0 then
    return nil
  end

  return { pos[1] + 1, pos[2] + 1 }
end

function M.new(opts)
  local state = opts.state
  local state_module = opts.state_module
  local insert_preview = opts.insert_preview

  local insert = {}
  insert.session_has_edits = false
  insert.session = nil
  insert.pending_simple = nil

  local function finish_lifecycle(lifecycle)
    if lifecycle and lifecycle.on_finish then
      lifecycle.on_finish()
    end
  end

  local function maybe_join_previous_change(lifecycle)
    if lifecycle and lifecycle.join_previous_change then
      pcall(vim.cmd, "silent! undojoin")
    end
  end

  local function stop_simple_insert(pending)
    if insert.pending_simple ~= pending then
      return
    end

    insert.pending_simple = nil
    if pending.autocmd_group then
      pcall(vim.api.nvim_del_augroup_by_id, pending.autocmd_group)
    end
    finish_lifecycle(pending.lifecycle)
  end

  local function apply_ranges(ranges, replacement)
    if #ranges == 0 then
      return {}
    end

    local buffer = vim.api.nvim_get_current_buf()
    local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-insert")
    local marks = {}

    for _, range in ipairs(ranges) do
      marks[#marks + 1] = {
        index = range.index,
        fallback = range.fallback,
        start_id = vim.api.nvim_buf_set_extmark(buffer, namespace, range.start_row, range.start_col, {
          right_gravity = false,
        }),
        end_id = vim.api.nvim_buf_set_extmark(buffer, namespace, range.end_row, range.end_col, {
          right_gravity = true,
        }),
      }
    end

    table.sort(marks, function(left, right)
      local left_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, left.end_id, {})
      local right_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, right.end_id, {})
      if left_pos[1] == right_pos[1] then
        return left_pos[2] > right_pos[2]
      end
      return left_pos[1] > right_pos[1]
    end)

    for order, mark in ipairs(marks) do
      local start_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.start_id, {})
      local end_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.end_id, {})
      if #start_pos > 0 and #end_pos > 0 then
        if insert.session_has_edits or order > 1 then
          pcall(vim.cmd, "silent! undojoin")
        end
        vim.api.nvim_buf_set_text(buffer, start_pos[1], start_pos[2], end_pos[1], end_pos[2], replacement)
        insert.session_has_edits = true
      end
    end

    local points = {}
    for _, mark in ipairs(marks) do
      local start_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.start_id, {})
      if #start_pos > 0 then
        points[mark.index] = advance_point({ start_pos[1] + 1, start_pos[2] + 1 }, replacement)
      elseif mark.fallback then
        points[mark.index] = mark.fallback
      end
    end

    vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
    return points
  end

  local function create_anchor_marks(anchor_specs, namespace_name)
    if not anchor_specs then
      return nil
    end

    local buffer = vim.api.nvim_get_current_buf()
    local namespace = vim.api.nvim_create_namespace(namespace_name)
    local marks = {}

    for index, spec in ipairs(anchor_specs) do
      if spec and spec.pos then
        marks[index] = vim.api.nvim_buf_set_extmark(buffer, namespace, spec.pos[1] - 1, spec.pos[2] - 1, {
          right_gravity = spec.right_gravity == true,
        })
      end
    end

    return {
      buffer = buffer,
      namespace = namespace,
      marks = marks,
    }
  end

  local function create_point_marks(points, namespace_name, right_gravity)
    local buffer = vim.api.nvim_get_current_buf()
    local namespace = vim.api.nvim_create_namespace(namespace_name)
    local marks = {}

    for index, point in ipairs(points) do
      marks[index] = vim.api.nvim_buf_set_extmark(buffer, namespace, point[1] - 1, point[2] - 1, {
        right_gravity = right_gravity == true,
      })
    end

    return {
      buffer = buffer,
      namespace = namespace,
      marks = marks,
    }
  end

  local function mark_positions(mark_state)
    if not mark_state then
      return {}
    end

    local positions = {}
    for index, mark_id in pairs(mark_state.marks) do
      positions[index] = extmark_pos_1indexed(mark_state.buffer, mark_state.namespace, mark_id)
    end

    return positions
  end

  local function clear_mark_state(mark_state)
    if mark_state then
      vim.api.nvim_buf_clear_namespace(mark_state.buffer, mark_state.namespace, 0, -1)
    end
  end

  local function cursor_points(entries)
    local points = {}

    for index, entry in ipairs(entries) do
      points[index] = entry.cursor_pos
    end

    return points
  end

  local function preview_entries(points, anchor_state, end_anchor_state, selection_config)
    return insert_preview.build_live(
      points,
      mark_positions(anchor_state),
      mark_positions(end_anchor_state),
      selection_config
    )
  end

  local function session_cursor_points(session)
    local points = mark_positions(session.end_state)
    if session.active and vim.api.nvim_get_current_buf() == session.buffer then
      points[1] = state_module.current_pos_1indexed()
    end

    if not session.active and session.selection_config.exit_cursor_left then
      for index, point in ipairs(points) do
        if point then
          points[index] = position.prev_pos(session.buffer, point)
        end
      end
    end

    return points
  end

  local function text_between_points(buffer, start_pos, end_pos)
    if not start_pos or not end_pos then
      return {}
    end

    local start_row, start_col = position.before_boundary(buffer, start_pos)
    local end_row, end_col = position.before_boundary(buffer, end_pos)

    if end_row < start_row or (end_row == start_row and end_col < start_col) then
      return {}
    end

    return vim.api.nvim_buf_get_text(buffer, start_row, start_col, end_row, end_col, {})
  end

  local function session_text_lines(session)
    local start_points = mark_positions(session.start_state)
    local end_points = mark_positions(session.end_state)
    return text_between_points(session.buffer, start_points[1], end_points[1])
  end

  local function secondary_ranges(session)
    local ranges = {}
    local start_points = mark_positions(session.start_state)
    local end_points = mark_positions(session.end_state)

    for index = 2, #start_points do
      local start_pos = start_points[index]
      local end_pos = end_points[index]
      if start_pos and end_pos then
        local start_row, start_col = position.before_boundary(session.buffer, start_pos)
        local end_row, end_col = position.before_boundary(session.buffer, end_pos)
        ranges[#ranges + 1] = {
          index = index,
          start_row = start_row,
          start_col = start_col,
          end_row = end_row,
          end_col = end_col,
          fallback = end_pos,
        }
      end
    end

    return ranges
  end

  local function refresh_session_preview(session)
    if not session.active or vim.api.nvim_get_current_buf() ~= session.buffer then
      return
    end

    local points = session_cursor_points(session)
    state.set_preview_entries(
      session.buffer,
      preview_entries(points, session.anchor_state, session.end_anchor_state, session.selection_config),
      { keep_cursor = true, cursor_positions = points, sync_history = false }
    )

    pcall(vim.api.nvim__redraw, {
      buf = session.buffer,
      valid = true,
      cursor = true,
      flush = true,
    })
  end

  local function sync_session_text(session)
    if not session.active or vim.api.nvim_get_current_buf() ~= session.buffer then
      return
    end

    session.applying = true

    local primary_lines = session_text_lines(session)
    if not vim.deep_equal(session.synced_lines, primary_lines) then
      local ranges = secondary_ranges(session)
      if #ranges > 0 then
        insert.session_has_edits = true
        apply_ranges(ranges, primary_lines)
      end
      session.synced_lines = vim.deepcopy(primary_lines)
    end

    refresh_session_preview(session)
    session.applying = false
  end

  local function stop_session()
    local session = insert.session
    if not session then
      return
    end

    sync_session_text(session)

    insert.session = nil
    session.active = false

    local final_points = session_cursor_points(session)
    if #final_points > 0 then
      state.set_preview_entries(
        session.buffer,
        preview_entries(final_points, session.anchor_state, session.end_anchor_state, session.selection_config),
        { keep_cursor = true, cursor_positions = final_points, sync_history = false }
      )
      state_module.move_cursor_to_pos(final_points[1])
    end

    finish_lifecycle(session.lifecycle)

    if session.autocmd_group then
      pcall(vim.api.nvim_del_augroup_by_id, session.autocmd_group)
    end

    clear_mark_state(session.anchor_state)
    clear_mark_state(session.end_anchor_state)
    clear_mark_state(session.start_state)
    clear_mark_state(session.end_state)
    state.exit_insert_mode({ consume_escape_once = true })
  end

  function insert.start(entries, config)
    config = config or {}
    local selection_config = config.selection or {}
    local lifecycle = config.lifecycle or {}
    state.exit_extend_mode()
    local active_entries = vim.deepcopy(entries)

    if insert.pending_simple then
      stop_simple_insert(insert.pending_simple)
    end

    if #entries <= 1 and not selection_config.selection_anchors then
      if entries[1] then
        state_module.move_cursor_to_pos(entries[1].cursor_pos)
      end

      if lifecycle.on_finish then
        local pending = {
          buffer = vim.api.nvim_get_current_buf(),
          lifecycle = lifecycle,
        }
        pending.autocmd_group = vim.api.nvim_create_augroup("axelcool1234-helix-simple-insert", { clear = false })
        insert.pending_simple = pending

        vim.api.nvim_create_autocmd("InsertLeave", {
          group = pending.autocmd_group,
          buffer = pending.buffer,
          callback = function()
            stop_simple_insert(pending)
          end,
        })
        vim.api.nvim_create_autocmd("BufLeave", {
          group = pending.autocmd_group,
          buffer = pending.buffer,
          callback = function()
            stop_simple_insert(pending)
          end,
        })
      end

      maybe_join_previous_change(lifecycle)
      vim.cmd("startinsert")
      return
    end

    insert.session_has_edits = false
    state.enter_insert_mode()
    if active_entries[1] then
      state_module.move_cursor_to_pos(active_entries[1].cursor_pos)
    end

    local session = {
      active = true,
      applying = false,
      buffer = vim.api.nvim_get_current_buf(),
      selection_config = selection_config,
      lifecycle = lifecycle,
      synced_lines = {},
      anchor_state = create_anchor_marks(selection_config.selection_anchors, "axelcool1234-helix-insert-anchor-start"),
      end_anchor_state = create_anchor_marks(selection_config.selection_ends, "axelcool1234-helix-insert-anchor-end"),
      start_state = create_point_marks(cursor_points(active_entries), "axelcool1234-helix-insert-cursor-start", false),
      end_state = create_point_marks(cursor_points(active_entries), "axelcool1234-helix-insert-cursor-end", true),
    }
    insert.session = session

    state.set_preview_entries(
      session.buffer,
      preview_entries(cursor_points(active_entries), session.anchor_state, session.end_anchor_state, selection_config),
      { keep_cursor = true, cursor_positions = cursor_points(active_entries), sync_history = false }
    )
    if active_entries[1] then
      state_module.move_cursor_to_pos(active_entries[1].cursor_pos)
    end

    session.autocmd_group = vim.api.nvim_create_augroup("axelcool1234-helix-insert-session", { clear = false })
    vim.api.nvim_create_autocmd("TextChangedI", {
      group = session.autocmd_group,
      buffer = session.buffer,
      callback = function()
        if insert.session ~= session or not session.active or session.applying then
          return
        end

        sync_session_text(session)
      end,
    })
    vim.api.nvim_create_autocmd("InsertLeave", {
      group = session.autocmd_group,
      buffer = session.buffer,
      callback = function()
        stop_session()
      end,
    })
    vim.api.nvim_create_autocmd("BufLeave", {
      group = session.autocmd_group,
      buffer = session.buffer,
      callback = function()
        stop_session()
      end,
    })

    refresh_session_preview(session)
    maybe_join_previous_change(lifecycle)
    vim.cmd("startinsert")
  end

  return insert
end

return M
