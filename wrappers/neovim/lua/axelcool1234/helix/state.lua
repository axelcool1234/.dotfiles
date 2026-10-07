local M = {}
local position = require("axelcool1234.helix.position")
local range_module = require("axelcool1234.helix.range")
local selection_module = require("axelcool1234.helix.selection")
local transaction_module = require("axelcool1234.helix.transaction")

local function current_buffer()
  return vim.api.nvim_get_current_buf()
end

local function current_window()
  return vim.api.nvim_get_current_win()
end

function M.current_pos_1indexed()
  local row, col0 = unpack(vim.api.nvim_win_get_cursor(0))
  local line = position.line_text(0, row)
  return { row, position.grapheme_col_from_byte_col0(line, col0) }
end

function M.move_cursor_to_pos(pos)
  local buffer = current_buffer()
  local row = math.max(1, math.min(pos[1], position.line_count(buffer)))
  local col = math.max(1, math.min(pos[2], position.cursor_max_column(buffer, row)))
  local line = position.line_text(buffer, row)
  vim.api.nvim_win_set_cursor(0, { row, position.byte_col0_from_grapheme_col(line, col) })
end

local function cursor_preview_cell(buffer, pos)
  local line = position.line_text(buffer, pos[1])
  local col = pos[2]
  local byte_col0 = position.byte_col0_from_grapheme_col(line, col)

  if line ~= "" and col >= 1 and col <= position.grapheme_count(line) then
    return {
      text = position.grapheme_at(line, col),
      extmark_col = byte_col0,
      end_col = position.byte_col0_from_grapheme_col(line, col + 1),
    }
  end

  return {
    text = " ",
    extmark_col = math.max(math.min(byte_col0, #line), 0),
    win_col = vim.fn.strdisplaywidth(position.prefix_by_grapheme_count(line, math.max(col - 1, 0))),
  }
end

local function ordered_ranges(selection)
  if not selection then
    return {}
  end
  local ranges = { selection.ranges[selection.primary_index] }
  for index, range in ipairs(selection.ranges) do
    if index ~= selection.primary_index then
      ranges[#ranges + 1] = range
    end
  end
  return ranges
end

local function copied_ordered_ranges(selection)
  local ranges = {}
  for index, range in ipairs(ordered_ranges(selection)) do
    ranges[index] = range:copy()
  end
  return ranges
end

function M.new(opts)
  local state = {
    preview = {
      buffer = nil,
      updating = false,
      selection_namespace = vim.api.nvim_create_namespace("axelcool1234-helix-selection"),
      cursor_namespace = vim.api.nvim_create_namespace("axelcool1234-helix-cursor"),
    },
    view_selections = {},
    extend_mode = false,
    insert_mode = false,
    consume_escape_once = false,
    sync_history_state = opts.sync_history_state,
    refresh_statusline = opts.refresh_statusline,
  }

  vim.g.helix_mode_label = vim.g.helix_mode_label or "NORMAL"

  local function view_bucket(win, create)
    win = win or current_window()
    local bucket = state.view_selections[win]
    if not bucket and create then
      bucket = {}
      state.view_selections[win] = bucket
    end
    return bucket
  end

  local function view_selection(win, buffer)
    local bucket = view_bucket(win, false)
    local saved = bucket and bucket[buffer or current_buffer()] or nil
    if not saved or not vim.api.nvim_buf_is_valid(saved.buffer) then
      return nil
    end
    return saved
  end

  local function clear_tracking(saved)
    if saved and saved.tracker then
      saved.tracker:clear()
    end
  end

  local function store_selection(win, selection)
    local buffer = selection.buffer
    local bucket = view_bucket(win, true)
    clear_tracking(bucket[buffer])
    local saved = {
      buffer = buffer,
      primary_index = selection.primary_index,
      changedtick = vim.api.nvim_buf_get_changedtick(buffer),
      tracker = transaction_module.track_ranges(buffer, selection.ranges, { affinity = "inside" }),
    }
    bucket[buffer] = saved
    return saved
  end

  local function resolve_selection(saved)
    if not saved then
      return nil
    end
    local changed = saved.changedtick ~= vim.api.nvim_buf_get_changedtick(saved.buffer)
    local ranges = saved.tracker:resolve({ keep = true, strict = true })
    if not ranges or #ranges == 0 then
      return nil
    end
    if changed then
      for _, range in ipairs(ranges) do
        range.goal_display_col = nil
      end
    end
    return selection_module.new(saved.buffer, ranges, math.min(saved.primary_index, #ranges))
  end

  local function active_selection()
    local saved = view_selection()
    return resolve_selection(saved)
  end

  local function clear_render()
    if state.preview.buffer and vim.api.nvim_buf_is_valid(state.preview.buffer) then
      vim.api.nvim_buf_clear_namespace(state.preview.buffer, state.preview.selection_namespace, 0, -1)
      vim.api.nvim_buf_clear_namespace(state.preview.buffer, state.preview.cursor_namespace, 0, -1)
    end
    state.preview.buffer = nil
  end

  local function refresh_mode_label()
    if state.insert_mode then
      vim.g.helix_mode_label = "INSERT"
    elseif state.extend_mode then
      vim.g.helix_mode_label = "SELECT"
    else
      vim.g.helix_mode_label = "NORMAL"
    end
    state.refresh_statusline()
  end

  function state.extend_mode_active()
    return state.extend_mode
  end

  function state.insert_mode_active()
    return state.insert_mode
  end

  function state.enter_extend_mode()
    state.extend_mode = true
    refresh_mode_label()
  end

  function state.exit_extend_mode()
    state.extend_mode = false
    refresh_mode_label()
  end

  function state.enter_insert_mode()
    state.insert_mode = true
    refresh_mode_label()
  end

  function state.exit_insert_mode(config)
    config = config or {}
    state.insert_mode = false
    if config.consume_escape_once == true then
      state.consume_escape_once = true
    end
    refresh_mode_label()
  end

  function state.consume_pending_escape()
    if not state.consume_escape_once then
      return false
    end
    state.consume_escape_once = false
    return true
  end

  function state.preview_active()
    local selection = active_selection()
    return selection ~= nil and #selection.ranges > 0
  end

  function state.selection_for_view(win)
    local saved = view_selection(win)
    return resolve_selection(saved)
  end

  function state.current_selection()
    local selection = active_selection()
    if selection then
      return selection:copy()
    end
    local pos = M.current_pos_1indexed()
    return selection_module.single(current_buffer(), range_module.from_cells(current_buffer(), pos, pos))
  end

  function state.preview_ranges()
    return copied_ordered_ranges(active_selection())
  end

  function state.preview_range(index)
    return state.preview_ranges()[index]
  end

  function state.preview_primary_index()
    return active_selection() and 1 or nil
  end

  function state.set_history_sync(callback)
    state.sync_history_state = callback
  end

  function state.clear_preview(config)
    config = config or {}
    clear_render()
    local bucket = view_bucket(nil, false)
    if bucket then
      clear_tracking(bucket[current_buffer()])
      bucket[current_buffer()] = nil
    end

    if config.keep_extend_mode ~= true then
      state.extend_mode = false
    end
    if config.keep_insert_mode ~= true then
      state.insert_mode = false
    end
    refresh_mode_label()
  end

  function state.refresh_preview()
    local selection = active_selection()
    clear_render()
    if not selection then
      return
    end

    local buffer = selection.buffer
    state.preview.buffer = buffer
    for index, range in ipairs(selection.ranges) do
      if not range.point and not range:is_empty() then
        local start_row, start_col, end_row, end_col = range:byte_range()
        vim.api.nvim_buf_set_extmark(buffer, state.preview.selection_namespace, start_row, start_col, {
          end_row = end_row,
          end_col = end_col,
          hl_group = "Visual",
        })
      end

      if index ~= selection.primary_index then
        local cursor_pos = range:cursor()
        local cursor_cell = cursor_preview_cell(buffer, cursor_pos)
        vim.api.nvim_buf_set_extmark(
          buffer,
          state.preview.cursor_namespace,
          cursor_pos[1] - 1,
          cursor_cell.extmark_col,
          vim.tbl_extend("force", {
            strict = false,
            hl_group = cursor_cell.end_col and "Cursor" or nil,
            end_col = cursor_cell.end_col,
            virt_text = { { cursor_cell.text, "Cursor" } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
            priority = 5000,
            right_gravity = false,
          }, cursor_cell.win_col and { virt_text_win_col = cursor_cell.win_col } or {})
        )
      end
    end
  end

  function state.activate_view(win)
    win = win or current_window()
    if win == current_window() then
      local selection = active_selection()
      if selection then
        M.move_cursor_to_pos(selection:primary():cursor())
      end
      state.refresh_preview()
    end
  end

  function state.deactivate_view()
    clear_render()
  end

  function state.clone_view(source_win, target_win)
    local source = view_bucket(source_win, false)
    if not source then
      return
    end
    for _, saved in pairs(source) do
      local selection = resolve_selection(saved)
      if selection then
        store_selection(target_win, selection)
      end
    end
  end

  function state.forget_view(win)
    local bucket = view_bucket(win, false)
    for _, saved in pairs(bucket or {}) do
      clear_tracking(saved)
    end
    state.view_selections[win] = nil
    if win == current_window() then
      clear_render()
    end
  end

  function state.forget_buffer(buffer)
    for _, bucket in pairs(state.view_selections) do
      local saved = bucket[buffer]
      if saved then
        clear_tracking(saved)
        bucket[buffer] = nil
      end
    end
    if state.preview.buffer == buffer then
      clear_render()
    end
  end

  function state.current_ranges()
    local entries = state.preview_ranges()
    if #entries > 0 then
      return entries
    end
    local pos = M.current_pos_1indexed()
    return { range_module.from_cells(current_buffer(), pos, pos) }
  end

  function state.primary_range()
    local selection = active_selection()
    if selection then
      return selection:primary()
    end
    return state.current_ranges()[1]
  end

  function state.set_preview_selection(selection, config)
    config = config or {}
    if not selection or #selection.ranges == 0 then
      return false
    end

    clear_render()
    state.preview.updating = true
    store_selection(current_window(), selection)

    local primary = selection:primary()
    if config.keep_cursor ~= true then
      M.move_cursor_to_pos(primary:cursor())
    end
    state.refresh_preview()

    if config.sync_history ~= false and state.sync_history_state then
      state.sync_history_state()
    end

    vim.schedule(function()
      state.preview.updating = false
    end)
    return true
  end

  function state.set_preview_ranges(buffer, entries, config)
    config = config or {}
    if #entries == 0 then
      state.clear_preview({ keep_extend_mode = true, keep_insert_mode = true })
      return false
    end

    local ranges = {}
    for index, entry in ipairs(entries) do
      ranges[index] = range_module.copy(buffer, entry)
    end

    local selection = selection_module.new(buffer, ranges, 1)
    return state.set_preview_selection(selection, config)
  end

  return state
end

return M
