local M = {}
local position = require("axelcool1234.helix.position")

local function pos_before(left, right)
  return left[1] < right[1] or (left[1] == right[1] and left[2] < right[2])
end

local function pos_after(left, right)
  return left[1] > right[1] or (left[1] == right[1] and left[2] > right[2])
end

local function pos_equal(left, right)
  return left[1] == right[1] and left[2] == right[2]
end

local function normalize_bounds(start_pos, end_pos)
  local start_copy = { math.max(1, start_pos[1]), math.max(1, start_pos[2]) }
  local end_copy = { math.max(1, end_pos[1]), math.max(1, end_pos[2]) }

  if pos_after(start_copy, end_copy) then
    start_copy, end_copy = end_copy, start_copy
  end

  return start_copy, end_copy
end

function M.selection_entry(anchor_pos, cursor_pos)
  local start_pos, end_pos = normalize_bounds(anchor_pos, cursor_pos)
  return {
    anchor_pos = { anchor_pos[1], anchor_pos[2] },
    cursor_pos = { cursor_pos[1], cursor_pos[2] },
    start_pos = start_pos,
    end_pos = end_pos,
  }
end

function M.entry_text_ranges(entry)
  local buffer = vim.api.nvim_get_current_buf()
  local start_row, start_col = position.before_boundary(buffer, entry.start_pos)
  local end_row, end_col = position.after_boundary(buffer, entry.end_pos)
  return start_row, start_col, end_row, end_col
end

function M.get_entry_text(entry)
  local start_row, start_col, end_row, end_col = M.entry_text_ranges(entry)
  local pieces = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})
  return table.concat(pieces, "\n")
end

function M.replace_entry_text(entry, replacement)
  local start_row, start_col, end_row, end_col = M.entry_text_ranges(entry)

  local lines
  if type(replacement) == "table" then
    lines = replacement
  elseif replacement == "" then
    lines = {}
  else
    lines = vim.split(replacement, "\n", { plain = true })
  end

  vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, lines)
end

function M.current_pos_1indexed()
  local row, col0 = unpack(vim.api.nvim_win_get_cursor(0))
  return { row, col0 + 1 }
end

local function buffer_cursor_max_column(buffer, row)
  return position.cursor_max_column(buffer, row)
end

function M.move_cursor_to_pos(pos)
  local buffer = vim.api.nvim_get_current_buf()
  local row = math.max(1, math.min(pos[1], vim.api.nvim_buf_line_count(buffer)))
  local col = math.max(1, math.min(pos[2], buffer_cursor_max_column(buffer, row)))
  vim.api.nvim_win_set_cursor(0, { row, math.max(col - 1, 0) })
end

local function cursor_preview_cell(buffer, pos)
  local line = vim.api.nvim_buf_get_lines(buffer, pos[1] - 1, pos[1], false)[1] or ""
  local col = pos[2]

  if line ~= "" and col >= 1 and col <= #line then
    return {
      text = line:sub(col, col),
      extmark_col = math.max(col - 1, 0),
      end_col = col,
    }
  end

  return {
    text = " ",
    extmark_col = math.max(math.min(col - 1, #line), 0),
    win_col = vim.fn.strdisplaywidth(line:sub(1, math.max(col - 1, 0))),
  }
end

local function entries_overlap(left, right)
  local left_start, left_end = left.start_pos, left.end_pos
  local right_start, right_end = right.start_pos, right.end_pos

  if pos_before(right_start, left_start) then
    left_start, left_end, right_start, right_end = right_start, right_end, left_start, left_end
  end

  return pos_after(left_end, right_start) or pos_equal(left_end, right_start)
end

local function entry_direction(entry)
  if pos_before(entry.anchor_pos, entry.cursor_pos) then
    return 1
  end

  if pos_after(entry.anchor_pos, entry.cursor_pos) then
    return -1
  end

  return 0
end

local function merged_entry_direction(left, right)
  local left_direction = entry_direction(left)
  local right_direction = entry_direction(right)

  if left_direction == right_direction then
    return left_direction
  end

  if left_direction == 0 then
    return right_direction
  end

  if right_direction == 0 then
    return left_direction
  end

  return right_direction
end

local function merge_two_entries(left, right)
  local start_pos = pos_before(left.start_pos, right.start_pos) and left.start_pos or right.start_pos
  local end_pos = pos_after(left.end_pos, right.end_pos) and left.end_pos or right.end_pos
  local direction = merged_entry_direction(left, right)

  if direction < 0 then
    return M.selection_entry(end_pos, start_pos)
  end

  return M.selection_entry(start_pos, end_pos)
end

local function sort_preview_items(items)
  table.sort(items, function(left, right)
    if pos_before(left.entry.start_pos, right.entry.start_pos) then
      return true
    end
    if pos_before(right.entry.start_pos, left.entry.start_pos) then
      return false
    end
    return pos_before(left.entry.end_pos, right.entry.end_pos)
  end)
end

local function merge_preview_items(items)
  if #items <= 1 then
    return items
  end

  local merged = {}
  for _, item in ipairs(items) do
    local merged_index = nil
    for index = #merged, 1, -1 do
      if entries_overlap(merged[index].entry, item.entry) then
        merged_index = index
        break
      end
    end

    if merged_index then
      local existing = merged[merged_index]
      merged[merged_index] = {
        entry = merge_two_entries(existing.entry, item.entry),
        cursor_pos = existing.is_primary and existing.cursor_pos or item.cursor_pos,
        preferred_col = existing.is_primary and existing.preferred_col or item.preferred_col,
        is_primary = existing.is_primary or item.is_primary,
      }
    else
      table.insert(merged, item)
    end
  end

  return merged
end

local function promote_primary_item(items)
  for index, item in ipairs(items) do
    if item.is_primary then
      if index ~= 1 then
        table.remove(items, index)
        table.insert(items, 1, item)
      end
      return
    end
  end
end

function M.new(opts)
  local state = {
    preview = {
      buffer = nil,
      entries = {},
      cursor_positions = nil,
      preferred_columns = nil,
      primary_index = nil,
      updating = false,
      selection_namespace = vim.api.nvim_create_namespace("axelcool1234-helix-selection"),
      cursor_namespace = vim.api.nvim_create_namespace("axelcool1234-helix-cursor"),
    },
    extend_mode = false,
    insert_mode = false,
    consume_escape_once = false,
    sync_history_state = opts.sync_history_state,
    refresh_statusline = opts.refresh_statusline,
  }

  vim.g.helix_mode_label = vim.g.helix_mode_label or "NORMAL"

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
    return state.preview.buffer == vim.api.nvim_get_current_buf() and #state.preview.entries > 0
  end

  function state.set_history_sync(callback)
    state.sync_history_state = callback
  end

  function state.clear_preview(config)
    config = config or {}

    if state.preview.buffer and vim.api.nvim_buf_is_valid(state.preview.buffer) then
      vim.api.nvim_buf_clear_namespace(state.preview.buffer, state.preview.selection_namespace, 0, -1)
      vim.api.nvim_buf_clear_namespace(state.preview.buffer, state.preview.cursor_namespace, 0, -1)
    end

    state.preview.buffer = nil
    state.preview.entries = {}
    state.preview.cursor_positions = nil
    state.preview.preferred_columns = nil
    state.preview.primary_index = nil

    if config.keep_extend_mode ~= true then
      state.extend_mode = false
    end
    if config.keep_insert_mode ~= true then
      state.insert_mode = false
    end
    refresh_mode_label()
  end

  function state.refresh_preview()
    if not state.preview_active() then
      return
    end

    vim.api.nvim_buf_clear_namespace(state.preview.buffer, state.preview.selection_namespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(state.preview.buffer, state.preview.cursor_namespace, 0, -1)

    for index, entry in ipairs(state.preview.entries) do
      local is_point = entry.start_pos[1] == entry.end_pos[1] and entry.start_pos[2] == entry.end_pos[2]
      local render_selection = not is_point or entry.force_highlight == true
      if render_selection then
        local start_row, start_col, end_row, end_col = M.entry_text_ranges(entry)
        vim.api.nvim_buf_set_extmark(
          state.preview.buffer,
          state.preview.selection_namespace,
          start_row,
          start_col,
          {
            end_row = end_row,
            end_col = end_col,
            hl_group = "Visual",
          }
        )
      end

      if index > 1 then
        local cursor_pos = state.preview.cursor_positions and state.preview.cursor_positions[index] or entry.cursor_pos
        local cursor_cell = cursor_preview_cell(state.preview.buffer, cursor_pos)
        vim.api.nvim_buf_set_extmark(
          state.preview.buffer,
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

  function state.current_entries()
    if state.preview_active() then
      return vim.deepcopy(state.preview.entries)
    end

    local pos = M.current_pos_1indexed()
    return { M.selection_entry(pos, pos) }
  end

  function state.primary_entry()
    if state.preview_active() then
      return state.preview.entries[state.preview.primary_index or 1]
    end

    return state.current_entries()[1]
  end

  function state.current_preferred_columns()
    if state.preview_active() and state.preview.preferred_columns then
      return vim.deepcopy(state.preview.preferred_columns)
    end

    local pos = M.current_pos_1indexed()
    return { pos[2] }
  end

  -- Preview entries are the single source of truth for Helix-style selections.
  -- The primary cursor is the real Neovim cursor; secondary cursors are rendered
  -- from the selection entries.
  function state.set_preview_entries(buffer, entries, config)
    config = config or {}

    local preview_items = {}
    for index, entry in ipairs(entries) do
      preview_items[index] = {
        entry = vim.deepcopy(entry),
        cursor_pos = config.cursor_positions and config.cursor_positions[index] or entry.cursor_pos,
        preferred_col = config.preferred_columns and config.preferred_columns[index] or entry.cursor_pos[2],
        is_primary = index == 1,
      }
    end

    sort_preview_items(preview_items)
    preview_items = merge_preview_items(preview_items)
    promote_primary_item(preview_items)

    state.clear_preview({ keep_extend_mode = true, keep_insert_mode = true })
    if #preview_items == 0 then
      return false
    end

    state.preview.updating = true
    if config.keep_cursor ~= true and preview_items[1] then
      M.move_cursor_to_pos(preview_items[1].cursor_pos)
    end

    state.preview.buffer = buffer
    state.preview.entries = {}
    state.preview.cursor_positions = {}
    state.preview.preferred_columns = {}
    state.preview.primary_index = 1
    for index, item in ipairs(preview_items) do
      state.preview.entries[index] = item.entry
      state.preview.cursor_positions[index] = vim.deepcopy(item.cursor_pos)
      state.preview.preferred_columns[index] = item.preferred_col
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

  return state
end

return M
