local state_module = require("axelcool1234.helix.state")
local motion_module = require("axelcool1234.helix.motion")
local insert_module = require("axelcool1234.helix.insert")
local history_module = require("axelcool1234.helix.history")
local insert_preview_module = require("axelcool1234.helix.insert_preview")
local registers_module = require("axelcool1234.helix.registers")
local match_module = require("axelcool1234.helix.match")
local position = require("axelcool1234.helix.position")

local M = {}
local selected_register_clear_ns = vim.api.nvim_create_namespace("axelcool1234-helix-selected-register")

local function refresh_lualine()
  local ok, lualine = pcall(require, "lualine")
  if ok then
    lualine.refresh({
      force = true,
      place = { "statusline" },
      trigger = "autocmd",
    })
  end
end

local function feedkeys(keys, mode)
  local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(termcodes, mode or "m", false)
end

local function getcharstr()
  local ok, char = pcall(vim.fn.getcharstr)
  if not ok or char == "\027" then
    return nil
  end

  return char
end

local state = state_module.new({
  refresh_statusline = refresh_lualine,
})

local motion = motion_module.new({
  state = state,
})

local insert_preview = insert_preview_module.new({
  state_module = state_module,
})

local insert = insert_module.new({
  state = state,
  state_module = state_module,
  insert_preview = insert_preview,
})

local history = history_module.new({
  state = state,
  state_module = state_module,
})

local match = match_module.new({
  state = state,
  state_module = state_module,
  position = position,
  history = history,
  getcharstr = getcharstr,
})

local registers = registers_module.new({
  state = state,
  state_module = state_module,
})

local last_modified_buffers = {}

history.attach()

local current_buffer
local line_text
local line_cursor_max_column
local line_supports_column
local pos_is_newline

local function entry_ends_after(left, right)
  if left.end_pos[1] == right.end_pos[1] then
    return left.end_pos[2] > right.end_pos[2]
  end
  return left.end_pos[1] > right.end_pos[1]
end

local replacement_lines

local function arm_selected_register_clear()
  vim.on_key(nil, selected_register_clear_ns)
  vim.on_key(function()
    vim.on_key(nil, selected_register_clear_ns)
    vim.schedule(function()
      registers.clear_selected()
    end)
  end, selected_register_clear_ns)
end

local function sync_cursors_to_points(points, config)
  if #points == 0 then
    return
  end
  local entries = {}
  for _, point in ipairs(points) do
    table.insert(entries, state_module.selection_entry(point, point))
  end
  state.set_preview_entries(vim.api.nvim_get_current_buf(), entries, config)
end

local function sync_cursors_to_entries(entries, config)
  if #entries == 0 then
    return
  end
  state.set_preview_entries(vim.api.nvim_get_current_buf(), entries, config)
end

local function match_lines(lines, pattern)
  local matches = {}

  for index, line in ipairs(lines) do
    local byteidx = 0

    while true do
      local match = vim.fn.matchstrpos(line, pattern, byteidx)
      local text = match[1]
      local start_col = match[2]
      local end_col = match[3]
      if start_col < 0 then
        break
      end

      table.insert(matches, {
        text = text,
        idx = index - 1,
        byteidx = start_col,
      })

      if end_col <= start_col then
        byteidx = start_col + 1
      else
        byteidx = end_col
      end

      if byteidx > #line then
        break
      end
    end
  end

  return matches
end

-- Selection edits are applied from extmark snapshots so buffer changes do not
-- invalidate later ranges. The returned start points are the post-edit insert
-- locations used by both `d` and `c`.
local function delete_preview_entries(entries)
  if #entries == 0 then
    return {}
  end

  local buffer = vim.api.nvim_get_current_buf()
  local namespace = vim.api.nvim_create_namespace("axelcool1234-delete-preview")
  local marks = {}

  local function delete_entry_range(entry)
    if entry.start_pos[1] == entry.end_pos[1] and entry.start_pos[2] == entry.end_pos[2] then
      local row = entry.cursor_pos[1]
      local line = line_text(row)
      local cursor_is_on_newline = position.is_newline_pos(buffer, entry.cursor_pos)

      if cursor_is_on_newline then
        return row - 1, #line, row, 0
      end
    end

    return state_module.entry_text_ranges(entry)
  end

  for index, entry in ipairs(entries) do
    local start_row, start_col, end_row, end_col = delete_entry_range(entry)
    marks[index] = {
      index = index,
      start_id = vim.api.nvim_buf_set_extmark(buffer, namespace, start_row, start_col, {
        right_gravity = false,
      }),
      end_id = vim.api.nvim_buf_set_extmark(buffer, namespace, end_row, end_col, {
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

  for _, mark in ipairs(marks) do
    local start_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.start_id, {})
    local end_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.end_id, {})
    if #start_pos > 0 and #end_pos > 0 then
      vim.api.nvim_buf_set_text(buffer, start_pos[1], start_pos[2], end_pos[1], end_pos[2], {})
    end
  end

  local start_points = {}
  for _, mark in ipairs(marks) do
    local start_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.start_id, {})
    if #start_pos > 0 then
      start_points[mark.index] = { start_pos[1] + 1, start_pos[2] + 1 }
    end
  end

  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
  return start_points
end

local function yank_preview_entries(entries)
  if #entries == 0 then
    return
  end

  local parts = {}
  for _, entry in ipairs(entries) do
    table.insert(parts, state_module.get_entry_text(entry))
  end

  vim.fn.setreg('"', table.concat(parts, "\n"))
end

local function replace_preview_entries_with_char(entries, replacement)
  if #entries == 0 then
    return {}
  end

  local buffer = vim.api.nvim_get_current_buf()
  local namespace = vim.api.nvim_create_namespace("axelcool1234-replace-preview-char")
  local sorted = vim.deepcopy(entries)
  local marks = {}

  local function replacement_end_pos(start_pos, lines)
    if #lines == 0 then
      return start_pos
    end

    if #lines == 1 then
      return { start_pos[1], start_pos[2] + #lines[1] - 1 }
    end

    return { start_pos[1] + #lines - 1, #lines[#lines] }
  end

  for index, entry in ipairs(entries) do
    local text = state_module.get_entry_text(entry)
    local count = vim.fn.strchars(text)
    if count < 1 then
      count = 1
    end
    local start_row, start_col, end_row, end_col = state_module.entry_text_ranges(entry)
    marks[index] = {
      index = index,
      entry = entry,
      count = count,
      start_id = vim.api.nvim_buf_set_extmark(buffer, namespace, start_row, start_col, {
        right_gravity = false,
      }),
    }
  end

  table.sort(sorted, function(left, right)
    return entry_ends_after(left, right)
  end)

  for _, entry in ipairs(sorted) do
    local text = state_module.get_entry_text(entry)
    local count = vim.fn.strchars(text)
    if count < 1 then
      count = 1
    end
    state_module.replace_entry_text(entry, replacement:rep(count))
  end

  local updated = {}
  for _, mark in ipairs(marks) do
    local start_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.start_id, {})
    if #start_pos > 0 then
      local start_1indexed = { start_pos[1] + 1, start_pos[2] + 1 }
      local lines = replacement_lines(replacement:rep(mark.count))
      local end_pos = replacement_end_pos(start_1indexed, lines)
      local original = mark.entry
      if original.start_pos[1] == original.end_pos[1] and original.start_pos[2] == original.end_pos[2] then
        updated[mark.index] = state_module.selection_entry(start_1indexed, start_1indexed)
      elseif original.anchor_pos[1] == original.start_pos[1] and original.anchor_pos[2] == original.start_pos[2] then
        updated[mark.index] = state_module.selection_entry(start_1indexed, end_pos)
      else
        updated[mark.index] = state_module.selection_entry(end_pos, start_1indexed)
      end
    end
  end

  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
  return updated
end

local function current_preview_entries()
  if not state.preview_active() then
    return {}
  end

  return vim.deepcopy(state.preview.entries)
end

replacement_lines = function(text)
  if text == "" then
    return {}
  end

  return vim.split(text, "\n", { plain = true })
end

local function current_preview_history_config()
  if not state.preview_active() then
    return {}
  end

  return {
    cursor_positions = vim.deepcopy(state.preview.cursor_positions or {}),
    preferred_columns = vim.deepcopy(state.preview.preferred_columns or {}),
  }
end

local function get_preview_lines(entry)
  local lines = vim.api.nvim_buf_get_lines(0, entry.start_pos[1] - 1, entry.end_pos[1], false)
  if #lines == 0 then
    return {}
  end

  lines[1] = lines[1]:sub(entry.start_pos[2])
  lines[#lines] = lines[#lines]:sub(1, entry.end_pos[2])
  return lines
end

local function compute_trimmed_bounds_from_entry(entry)
  local lines = get_preview_lines(entry)
  local first_line_idx, first_col
  local last_line_idx, last_col

  for index, line in ipairs(lines) do
    local start_idx = line:find("%S")
    if start_idx then
      first_line_idx = index
      first_col = start_idx
      break
    end
  end

  for index = #lines, 1, -1 do
    local line = lines[index]
    for col = #line, 1, -1 do
      if line:sub(col, col):match("%S") then
        last_line_idx = index
        last_col = col
        break
      end
    end
    if last_line_idx then
      break
    end
  end

  if not first_line_idx or not last_line_idx then
    return nil
  end

  local start_row = entry.start_pos[1] + first_line_idx - 1
  local start_col = first_line_idx == 1 and (entry.start_pos[2] + first_col - 1) or first_col
  local end_row = entry.start_pos[1] + last_line_idx - 1
  local end_col = last_line_idx == 1 and (entry.start_pos[2] + last_col - 1) or last_col

  return { start_row, start_col }, { end_row, end_col }
end

local function compile_selection_regex(pattern)
  local compiled = pattern
  if vim.o.ignorecase then
    if vim.o.smartcase and pattern:find("[A-Z]") then
      compiled = "\\C" .. compiled
    else
      compiled = "\\c" .. compiled
    end
  end
  compiled = "\\v" .. compiled

  return compiled
end

local function prompt_selection_regex(prompt)
  local pattern = vim.fn.input(prompt .. ": ")
  if pattern == "" then
    return nil
  end

  local compiled = compile_selection_regex(pattern)

  local ok, err = pcall(function()
    match_lines({ "" }, compiled)
  end)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end

  return compiled
end

local function bytecol_to_charcol(row, bytecol)
  local line = line_text(row)
  return vim.str_utfindex(line:sub(1, math.max(bytecol - 1, 0))) + 1
end

local last_search_pattern = nil

local function search_match_entry(entry, pattern, direction)
  local buffer = current_buffer()
  direction = direction or "forward"
  local start_pos = direction == "backward"
    and position.prev_pos(buffer, entry.start_pos)
    or position.next_pos(buffer, entry.end_pos)
  local saved_view = vim.fn.winsaveview()
  local flags = direction == "backward" and "bnw" or "nw"

  state_module.move_cursor_to_pos(start_pos)
  local start_match = vim.fn.searchpos(pattern, flags)
  vim.fn.winrestview(saved_view)

  if start_match[1] == 0 then
    return nil
  end

  local matches = vim.fn.matchbufline(buffer, pattern, start_match[1], start_match[1])
  local match = nil
  for _, candidate in ipairs(matches) do
    if candidate.lnum == start_match[1] and candidate.byteidx == start_match[2] - 1 then
      match = candidate
      break
    end
  end

  if not match or match.text == "" then
    return nil
  end

  local start_charcol = bytecol_to_charcol(start_match[1], start_match[2])
  local end_bytecol = match.byteidx + #match.text
  local end_charcol = bytecol_to_charcol(start_match[1], end_bytecol)
  return state_module.selection_entry({ start_match[1], start_charcol }, { start_match[1], end_charcol })
end

local function apply_search_match(pattern, direction)
  local source_entries = state.preview_active() and current_preview_entries() or state.current_entries()
  local match_entry = search_match_entry(source_entries[1], pattern, direction)
  if not match_entry then
    vim.api.nvim_echo({ { "no more matches", "WarningMsg" } }, false, {})
    return
  end

  local entries = { match_entry }

  if state.extend_mode_active() then
    for _, entry in ipairs(source_entries) do
      table.insert(entries, entry)
    end
    state.set_preview_entries(current_buffer(), entries)
    return
  end

  if state.preview_active() and #source_entries > 1 then
    for index = 2, #source_entries do
      table.insert(entries, source_entries[index])
    end
  end

  state.set_preview_entries(current_buffer(), entries)
  state.exit_extend_mode()
end

function M.search_regex()
  local pattern = prompt_selection_regex("search")
  if not pattern then
    return
  end

  last_search_pattern = pattern
  apply_search_match(pattern, "forward")
end

function M.search_regex_backward()
  local pattern = prompt_selection_regex("search backward")
  if not pattern then
    return
  end

  last_search_pattern = pattern
  apply_search_match(pattern, "backward")
end

function M.search_next(direction)
  direction = direction or "forward"
  if not last_search_pattern then
    vim.api.nvim_echo({ { "no previous search", "WarningMsg" } }, false, {})
    return
  end

  apply_search_match(last_search_pattern, direction)
end

local function preview_entry_matches(entry, pattern)
  local lines = get_preview_lines(entry)
  local matches = match_lines(lines, pattern)
  return #matches > 0
end

local function echo_selection_message(message)
  vim.api.nvim_echo({ { message, "WarningMsg" } }, false, {})
end

local function entry_regex_matches(entry, pattern)
  local lines = get_preview_lines(entry)
  local matches = match_lines(lines, pattern)
  local entries = {}

  for _, match in ipairs(matches) do
    local row = entry.start_pos[1] + match.idx
    local start_col = match.idx == 0 and (entry.start_pos[2] + match.byteidx) or (match.byteidx + 1)
    local width = math.max(#match.text, 1)
    local end_col = start_col + width - 1
    table.insert(entries, state_module.selection_entry({ row, start_col }, { row, end_col }))
  end

  return entries
end

function current_buffer()
  return vim.api.nvim_get_current_buf()
end

function line_text(row)
  return position.line_text(current_buffer(), row)
end

function line_cursor_max_column(row)
  return position.cursor_max_column(current_buffer(), row)
end

function line_supports_column(row, col)
  return position.supports_column(current_buffer(), row, col)
end

function pos_is_newline(row, col)
  return position.is_newline_pos(current_buffer(), { row, col })
end

local function point_entry(pos)
  return state_module.selection_entry(pos, pos)
end

local function after_entry_point(entry)
  return position.next_pos(current_buffer(), entry.end_pos)
end

local function repeated_register_values(values, count)
  if #values == 0 or count <= 0 then
    return {}
  end

  local expanded = {}
  local last = values[#values]
  for index = 1, count do
    expanded[index] = values[index] or last
  end
  return expanded
end

local function repeated_text(text, count)
  if count <= 1 then
    return text
  end

  return string.rep(text, count)
end

local function toggled_case_text(text)
  return (text:gsub("%a", function(char)
    local lower = string.lower(char)
    if char == lower then
      return string.upper(char)
    end

    return lower
  end))
end

local function insert_points_with_text(points, replacements)
  if #points == 0 or #replacements == 0 then
    return {}
  end

  local buffer = vim.api.nvim_get_current_buf()
  local namespace = vim.api.nvim_create_namespace("axelcool1234-insert-points")
  local marks = {}

  for index, point in ipairs(points) do
    local row, col = position.before_boundary(buffer, point)
    marks[index] = {
      index = index,
      start_id = vim.api.nvim_buf_set_extmark(buffer, namespace, row, col, {
        right_gravity = false,
      }),
      end_id = vim.api.nvim_buf_set_extmark(buffer, namespace, row, col, {
        right_gravity = true,
      }),
      replacement = replacements[index],
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

  for _, mark in ipairs(marks) do
    local start_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.start_id, {})
    if #start_pos > 0 then
      vim.api.nvim_buf_set_text(
        buffer,
        start_pos[1],
        start_pos[2],
        start_pos[1],
        start_pos[2],
        replacement_lines(mark.replacement)
      )
    end
  end

  local updated = {}
  for _, mark in ipairs(marks) do
    local start_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.start_id, {})
    local end_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.end_id, {})
    if #start_pos > 0 and #end_pos > 0 then
      local start_1indexed = { start_pos[1] + 1, start_pos[2] + 1 }
      local end_1indexed = { end_pos[1] + 1, end_pos[2] + 1 }
      if start_1indexed[1] == end_1indexed[1] and start_1indexed[2] == end_1indexed[2] then
        updated[mark.index] = state_module.selection_entry(start_1indexed, start_1indexed)
      else
        updated[mark.index] = state_module.selection_entry(start_1indexed, position.prev_pos(buffer, end_1indexed))
      end
    end
  end

  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
  return updated
end

local function insertion_entries_and_selection(entries, edge)
  local collapsed = {}
  local anchors = {}
  local has_selection = false
  for _, entry in ipairs(entries) do
    if edge == "start" then
      table.insert(collapsed, point_entry(entry.start_pos))
      if entry.start_pos[1] ~= entry.end_pos[1] or entry.start_pos[2] ~= entry.end_pos[2] then
        has_selection = true
        table.insert(anchors, {
          pos = entry.start_pos,
          right_gravity = true,
        })
      else
        table.insert(anchors, nil)
      end
    else
      table.insert(collapsed, point_entry(after_entry_point(entry)))
      if entry.start_pos[1] ~= entry.end_pos[1] or entry.start_pos[2] ~= entry.end_pos[2] then
        has_selection = true
        table.insert(anchors, {
          pos = entry.start_pos,
          right_gravity = false,
        })
      else
        table.insert(anchors, {
          pos = entry.cursor_pos,
          right_gravity = false,
        })
      end
    end
  end

  if edge == "start" then
    local ends = {}
    for _, entry in ipairs(entries) do
      if entry.start_pos[1] ~= entry.end_pos[1] or entry.start_pos[2] ~= entry.end_pos[2] then
        table.insert(ends, {
          pos = entry.end_pos,
          right_gravity = true,
        })
      else
        table.insert(ends, nil)
      end
    end

    return collapsed, {
      selection_anchors = anchors,
      selection_ends = ends,
      preview_entries = has_selection and "between_anchors" or nil,
    }
  end

  return collapsed, {
    selection_anchors = anchors,
    exit_cursor_left = true,
  }
end

local function preview_or_cursor_entries()
  return state.current_entries()
end

local function set_preview_entries(entries, config)
  return state.set_preview_entries(vim.api.nvim_get_current_buf(), entries, config)
end

local function selected_or_explicit_register(register_name)
  return register_name or registers.take_selected()
end

local function store_yanked_entries(entries, register_name)
  local parts = {}
  for _, entry in ipairs(entries) do
    table.insert(parts, state_module.get_entry_text(entry))
  end

  if #parts == 0 then
    return true
  end

  local ok, err = registers.write(register_name, parts)
  if not ok then
    if err then
      vim.notify(err, vim.log.levels.ERROR)
    end
    return false
  end

  return true
end

local function replace_preview_entries_with_text(entries, replacements)
  if #entries == 0 or #replacements == 0 then
    return {}
  end

  local function replacement_end_pos(start_pos, text)
    local lines = replacement_lines(text)
    if #lines == 0 then
      return start_pos
    end

    if #lines == 1 then
      return { start_pos[1], start_pos[2] + #lines[1] - 1 }
    end

    return { start_pos[1] + #lines - 1, #lines[#lines] }
  end

  local buffer = vim.api.nvim_get_current_buf()
  local namespace = vim.api.nvim_create_namespace("axelcool1234-replace-preview")
  local marks = {}

  for index, entry in ipairs(entries) do
    local start_row, start_col, end_row, end_col = state_module.entry_text_ranges(entry)
    marks[index] = {
      index = index,
      entry = entry,
      replacement = replacements[math.min(index, #replacements)],
      start_id = vim.api.nvim_buf_set_extmark(buffer, namespace, start_row, start_col, {
        right_gravity = false,
      }),
      end_id = vim.api.nvim_buf_set_extmark(buffer, namespace, end_row, end_col, {
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

  for _, mark in ipairs(marks) do
    local start_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.start_id, {})
    local end_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.end_id, {})
    if #start_pos > 0 and #end_pos > 0 then
      vim.api.nvim_buf_set_text(
        buffer,
        start_pos[1],
        start_pos[2],
        end_pos[1],
        end_pos[2],
        replacement_lines(mark.replacement)
      )
    end
  end

  local updated_entries = {}
  for _, mark in ipairs(marks) do
    local start_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.start_id, {})
    if #start_pos > 0 then
      local start_1indexed = { start_pos[1] + 1, start_pos[2] + 1 }
      local end_selected = replacement_end_pos(start_1indexed, mark.replacement)
      if start_1indexed[1] == end_selected[1] and start_1indexed[2] == end_selected[2] then
        updated_entries[mark.index] = state_module.selection_entry(start_1indexed, start_1indexed)
        updated_entries[mark.index].force_highlight = true
      else
        if mark.entry.anchor_pos[1] > mark.entry.cursor_pos[1]
          or (mark.entry.anchor_pos[1] == mark.entry.cursor_pos[1] and mark.entry.anchor_pos[2] > mark.entry.cursor_pos[2]) then
          updated_entries[mark.index] = state_module.selection_entry(end_selected, start_1indexed)
        else
          updated_entries[mark.index] = state_module.selection_entry(start_1indexed, end_selected)
        end
      end
    end
  end

  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
  return updated_entries
end

local function full_line_entry(row_start, row_end)
  row_end = row_end or row_start
  return state_module.selection_entry({ row_start, 1 }, { row_end, line_cursor_max_column(row_end) })
end

local function linewise_entries(entries)
  local line_entries = {}
  for _, entry in ipairs(entries) do
    line_entries[#line_entries + 1] = full_line_entry(entry.start_pos[1], entry.end_pos[1])
  end

  return line_entries
end

local function create_entry_marks(buffer, entries, namespace)
  local marks = {}
  for index, entry in ipairs(entries) do
    local anchor_row, anchor_col = position.before_boundary(buffer, entry.anchor_pos)
    local cursor_row, cursor_col = position.before_boundary(buffer, entry.cursor_pos)
    marks[index] = {
      anchor_id = vim.api.nvim_buf_set_extmark(buffer, namespace, anchor_row, anchor_col, {
        right_gravity = true,
      }),
      cursor_id = vim.api.nvim_buf_set_extmark(buffer, namespace, cursor_row, cursor_col, {
        right_gravity = true,
      }),
    }
  end

  return marks
end

local function extmark_pos_1indexed(buffer, namespace, mark_id)
  local pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark_id, {})
  if #pos == 0 then
    return nil
  end

  return { pos[1] + 1, pos[2] + 1 }
end

local function restore_entries_from_marks(buffer, entries, namespace, marks)
  local restored = {}
  for index, entry in ipairs(entries) do
    local mark = marks[index]
    local anchor_pos = extmark_pos_1indexed(buffer, namespace, mark.anchor_id) or entry.anchor_pos
    local cursor_pos = extmark_pos_1indexed(buffer, namespace, mark.cursor_id) or entry.cursor_pos
    restored[index] = state_module.selection_entry(anchor_pos, cursor_pos)
  end

  return restored
end

local function merged_line_ranges(entries)
  local ranges = {}
  for _, entry in ipairs(entries) do
    ranges[#ranges + 1] = { start_row = entry.start_pos[1], end_row = entry.end_pos[1] }
  end

  table.sort(ranges, function(left, right)
    if left.start_row == right.start_row then
      return left.end_row < right.end_row
    end

    return left.start_row < right.start_row
  end)

  local merged = {}
  for _, range in ipairs(ranges) do
    local last = merged[#merged]
    if last and range.start_row <= last.end_row + 1 then
      last.end_row = math.max(last.end_row, range.end_row)
    else
      merged[#merged + 1] = { start_row = range.start_row, end_row = range.end_row }
    end
  end

  return merged
end

local function linewise_entry_from_entry(entry, end_row)
  local start_pos = { entry.start_pos[1], 1 }
  local end_pos = { end_row, line_cursor_max_column(end_row) }

  if entry.anchor_pos[1] > entry.cursor_pos[1]
    or (entry.anchor_pos[1] == entry.cursor_pos[1] and entry.anchor_pos[2] > entry.cursor_pos[2]) then
    return state_module.selection_entry(end_pos, start_pos)
  end

  return state_module.selection_entry(start_pos, end_pos)
end

local function entry_is_full_line(entry)
  return entry.start_pos[2] == 1 and entry.end_pos[2] == line_cursor_max_column(entry.end_pos[1])
end

local function entry_is_point(entry)
  return entry.anchor_pos[1] == entry.cursor_pos[1] and entry.anchor_pos[2] == entry.cursor_pos[2]
end

local function clone_entry_to_supported_line(entry, delta, preferred_cursor_col)
  local cursor_row_delta = delta > 0 and 1 or -1
  local row_offset = entry.anchor_pos[1] - entry.cursor_pos[1]
  local target_cursor_row = entry.cursor_pos[1] + delta
  local last_row = position.line_count(current_buffer())

  if entry_is_point(entry) then
    local target_col = preferred_cursor_col or entry.cursor_pos[2]

    while target_cursor_row >= 1 and target_cursor_row <= last_row do
      if line_supports_column(target_cursor_row, target_col) then
        return state_module.selection_entry({ target_cursor_row, target_col }, { target_cursor_row, target_col })
      end

      target_cursor_row = target_cursor_row + cursor_row_delta
    end

    return nil
  end

  while target_cursor_row >= 1 and target_cursor_row <= last_row do
    local target_anchor_row = target_cursor_row + row_offset
    if target_anchor_row >= 1
      and target_anchor_row <= last_row
      and line_supports_column(target_anchor_row, entry.anchor_pos[2])
      and line_supports_column(target_cursor_row, entry.cursor_pos[2]) then
      return state_module.selection_entry(
        { target_anchor_row, entry.anchor_pos[2] },
        { target_cursor_row, entry.cursor_pos[2] }
      )
    end

    target_cursor_row = target_cursor_row + cursor_row_delta
  end

  return nil
end

local function selection_segments_by_line(entry)
  local function shift_cursor_off_newline(segment)
    if not position.is_newline_pos(current_buffer(), segment.cursor_pos) then
      return segment
    end

    if line_text(segment.cursor_pos[1]) == "" then
      return segment
    end

    local shifted_cursor = position.prev_pos(current_buffer(), segment.cursor_pos)
    if segment.anchor_pos[1] == segment.cursor_pos[1] and segment.anchor_pos[2] == segment.cursor_pos[2] then
      return state_module.selection_entry(shifted_cursor, shifted_cursor)
    end

    return state_module.selection_entry(segment.anchor_pos, shifted_cursor)
  end

  local segments = {}

  for row = entry.start_pos[1], entry.end_pos[1] do
    local start_col = row == entry.start_pos[1] and entry.start_pos[2] or 1
    local end_col = row == entry.end_pos[1] and entry.end_pos[2] or line_cursor_max_column(row)
    if start_col > end_col then
      start_col = end_col
    end

    table.insert(segments, shift_cursor_off_newline(state_module.selection_entry({ row, start_col }, { row, end_col })))
  end

  return segments
end

function M.exit_select_mode()
  if state.consume_pending_escape() then
    return
  end

  if state.preview_active() or state.extend_mode_active() then
    state.exit_extend_mode()
    return
  end
  feedkeys("<Esc>", "n")
end

function M.normal_motion(keys)
  return motion.normal(keys)
end

function M.apply_word_motion(target)
  motion.apply_word(target)
end

function M.find_char_motion(kind)
  return function()
    local char = getcharstr()
    if not char then
      return
    end

    motion.find_char(kind, char)
  end
end

function M.scroll_half_page(direction)
  motion.scroll_half_page(direction)
end

function M.goto_last_line()
  motion.goto_last_line()
end

function M.goto_line()
  motion.goto_line()
end

function M.goto_file_start()
  local target_row = vim.v.count > 0 and vim.v.count or 1
  local buffer = current_buffer()
  local last_row = position.line_count(buffer)
  local source_entries = state.current_entries()
  local entries = {}
  local preferred_columns = {}

  target_row = math.max(1, math.min(target_row, last_row))

  for index, source_entry in ipairs(source_entries) do
    local target = { target_row, 1 }
    if state.extend_mode_active() then
      local anchor = state.preview.entries[index] and state.preview.entries[index].anchor_pos or source_entry.anchor_pos
      entries[index] = state_module.selection_entry(anchor, target)
    else
      entries[index] = state_module.selection_entry(target, target)
    end
    preferred_columns[index] = 1
  end

  if #source_entries > 1 or state.extend_mode_active() or state.preview_active() then
    state.set_preview_entries(buffer, entries, { preferred_columns = preferred_columns })
    if not state.extend_mode_active() then
      state.exit_extend_mode()
    end
    return
  end

  state_module.move_cursor_to_pos(entries[1].cursor_pos)
end

function M.goto_column()
  motion.normal("|")()
end

function M.goto_line_start()
  local buffer = current_buffer()
  local source_entries = state.current_entries()
  local entries = {}
  local preferred_columns = {}

  for index, source_entry in ipairs(source_entries) do
    local target = { source_entry.cursor_pos[1], 1 }
    if state.extend_mode_active() then
      local anchor = state.preview.entries[index] and state.preview.entries[index].anchor_pos or source_entry.anchor_pos
      entries[index] = state_module.selection_entry(anchor, target)
    else
      entries[index] = state_module.selection_entry(target, target)
    end
    preferred_columns[index] = 1
  end

  if #source_entries > 1 or state.extend_mode_active() or state.preview_active() then
    state.set_preview_entries(buffer, entries, { preferred_columns = preferred_columns })
    if not state.extend_mode_active() then
      state.exit_extend_mode()
    end
    return
  end

  state_module.move_cursor_to_pos(entries[1].cursor_pos)
end

function M.goto_line_end()
  motion.normal("$")()
end

function M.goto_first_nonblank()
  motion.normal("^")()
end

function M.move_textual_line_down()
  motion.normal("j")()
end

function M.goto_window_position(keys)
  motion.normal(keys)()
end

function M.goto_last_accessed_file()
  local alt = vim.fn.bufnr("#")
  local current = vim.api.nvim_get_current_buf()
  if alt > 0 and alt ~= current and vim.api.nvim_buf_is_valid(alt) then
    vim.cmd.buffer({ args = { tostring(alt) } })
    return
  end

  vim.notify("no last accessed buffer", vim.log.levels.WARN)
end

function M.goto_last_modified_file()
  local current = vim.api.nvim_get_current_buf()
  for index, buf in ipairs(last_modified_buffers) do
    if not vim.api.nvim_buf_is_valid(buf) or buf == current then
      table.remove(last_modified_buffers, index)
    else
      vim.cmd.buffer({ args = { tostring(buf) } })
      return
    end
  end

  vim.notify("no last modified buffer", vim.log.levels.WARN)
end

function M.goto_last_modification()
  motion.normal("g;")()
end

local function change_entry_from_hunk(hunk, direction)
  local start_row = math.max(hunk.added.start, 1)
  local end_row = math.max(hunk.vend, start_row)
  end_row = math.min(end_row, vim.api.nvim_buf_line_count(current_buffer()))
  local start_pos = { start_row, 1 }
  local end_pos = { end_row, line_cursor_max_column(end_row) }
  if direction == "backward" then
    return state_module.selection_entry(end_pos, start_pos)
  end
  return state_module.selection_entry(start_pos, end_pos)
end

function M.goto_change(kind)
  local cache = require("gitsigns.cache").cache[current_buffer()]
  if not cache then
    vim.notify("Diff is not available in current buffer", vim.log.levels.WARN)
    return
  end

  local hunks = cache:get_hunks(false, false)
  if not hunks or #hunks == 0 then
    return
  end

  local find_nearest_hunk = require("gitsigns.hunks").find_nearest_hunk
  local source_entries = preview_or_cursor_entries()
  local entries = {}
  local in_extend_mode = state.extend_mode_active()

  for entry_index, entry in ipairs(source_entries) do
    local row = (state.preview_active() and state.preview.cursor_positions[entry_index] or entry.cursor_pos)[1]
    local hunk_index = find_nearest_hunk(row, hunks, kind, false)
    if hunk_index then
      local direction = (kind == "prev" or kind == "first") and "backward" or "forward"
      local hunk_entry = change_entry_from_hunk(hunks[hunk_index], direction)
      if in_extend_mode then
        local anchor = (state.preview_active() and state.preview.entries[entry_index] and state.preview.entries[entry_index].anchor_pos) or entry.anchor_pos
        local target_pos = hunk_entry.end_pos
        if hunk_entry.end_pos[1] < anchor[1]
          or (hunk_entry.end_pos[1] == anchor[1] and hunk_entry.end_pos[2] < anchor[2]) then
          target_pos = hunk_entry.start_pos
        end
        entries[#entries + 1] = state_module.selection_entry(anchor, target_pos)
      else
        entries[#entries + 1] = hunk_entry
      end
    else
      entries[#entries + 1] = entry
    end
  end

  set_preview_entries(entries)
  if not in_extend_mode then
    state.exit_extend_mode()
  end
end

function M.goto_textobject(object_name, direction)
  match.goto_textobject(object_name, direction)
end

local function line_is_blank_text(row)
  return line_text(row):match("^%s*$") ~= nil
end

function M.goto_paragraph(direction)
  local buffer = current_buffer()
  local last_row = position.line_count(buffer)

  local function paragraph_start_at_or_before(row)
    local line = row
    while line > 1 and line_is_blank_text(line) do
      line = line - 1
    end
    while line > 1 and not line_is_blank_text(line - 1) do
      line = line - 1
    end
    return line
  end

  local function paragraph_end_at_or_after(row)
    local line = row
    while line < last_row and line_is_blank_text(line) do
      line = line + 1
    end
    while line < last_row and not line_is_blank_text(line + 1) do
      line = line + 1
    end
    return line
  end

  local function paragraph_start_after(row)
    local line = row
    while line < last_row and not line_is_blank_text(line) do
      line = line + 1
    end
    while line < last_row and line_is_blank_text(line) do
      line = line + 1
    end
    return line
  end

  local function blank_block_end(row)
    local line = row
    while line < last_row and line_is_blank_text(line + 1) do
      line = line + 1
    end
    return line
  end

  local source_entries = preview_or_cursor_entries()
  local entries = {}
  local cursor_positions = {}
  local in_extend_mode = state.extend_mode_active()
  for index, entry in ipairs(source_entries) do
    local cursor = state.preview_active() and state.preview.cursor_positions[index] or entry.cursor_pos
    local row = cursor[1]
    local anchor = (state.preview_active() and state.preview.entries[index] and state.preview.entries[index].anchor_pos) or entry.anchor_pos
    local normal_entry
    local target_cursor_pos
    if direction == "forward" then
      local end_row = line_is_blank_text(row) and row or paragraph_end_at_or_after(row)
      if line_is_blank_text(row) then
        if not state.preview_active() then
          local blank_end = blank_block_end(row)
          target_cursor_pos = { blank_end, line_cursor_max_column(blank_end) }
          normal_entry = state_module.selection_entry(cursor, target_cursor_pos)
        else
          local start_row = paragraph_start_after(row)
          if start_row == last_row and not line_is_blank_text(start_row) then
            target_cursor_pos = { start_row, line_cursor_max_column(start_row) }
            normal_entry = state_module.selection_entry({ start_row, 1 }, target_cursor_pos)
          else
            local target = paragraph_start_after(start_row)
            target_cursor_pos = position.prev_pos(buffer, { target, 1 })
            normal_entry = state_module.selection_entry({ start_row, 1 }, target_cursor_pos)
          end
        end
      elseif row == end_row and cursor[2] == line_cursor_max_column(row) then
        local start_row = paragraph_start_after(row)
        local object_entry = match.select_textobject_at_point({ start_row, 1 }, "p", false)
        normal_entry = object_entry
        target_cursor_pos = object_entry.cursor_pos
      else
        local target = paragraph_start_after(row)
        if target == last_row and not line_is_blank_text(target) then
          target_cursor_pos = { target, line_cursor_max_column(target) }
          normal_entry = state_module.selection_entry(cursor, target_cursor_pos)
        else
          target_cursor_pos = position.prev_pos(buffer, { target, 1 })
          normal_entry = state_module.selection_entry(cursor, target_cursor_pos)
        end
      end
    else
      local start_row_here = line_is_blank_text(row) and row or paragraph_start_at_or_before(row)
      if line_is_blank_text(row) or (row == start_row_here and cursor[2] == 1) then
        local start_row = paragraph_start_at_or_before(math.max(row - 1, 1))
        local target = paragraph_start_after(start_row)
        if target == last_row and not line_is_blank_text(target) then
          target_cursor_pos = { target, line_cursor_max_column(target) }
        else
          target_cursor_pos = position.prev_pos(buffer, { target, 1 })
        end
        normal_entry = state_module.selection_entry({ start_row, 1 }, target_cursor_pos)
        target_cursor_pos = { start_row, 1 }
      else
        local target_row = paragraph_start_at_or_before(math.max(row - 1, 1))
        target_cursor_pos = { target_row, 1 }
        normal_entry = state_module.selection_entry(position.prev_pos(buffer, cursor), target_cursor_pos)
      end
    end

    if in_extend_mode then
      entries[#entries + 1] = state_module.selection_entry(anchor, target_cursor_pos)
      cursor_positions[#cursor_positions + 1] = target_cursor_pos
    else
      entries[#entries + 1] = normal_entry
      cursor_positions[#cursor_positions + 1] = target_cursor_pos
    end
  end

  set_preview_entries(entries, { cursor_positions = cursor_positions })
  if not in_extend_mode then
    state.exit_extend_mode()
  end
end

function M.add_newline_relative(direction)
  local entries = preview_or_cursor_entries()
  local buffer = current_buffer()
  local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-add-newline")
  local marks = {}
  local count = vim.v.count1

  for index, entry in ipairs(entries) do
    local row = direction > 0 and entry.end_pos[1] or entry.start_pos[1] - 1
    marks[index] = {
      id = vim.api.nvim_buf_set_extmark(buffer, namespace, math.max(row, 0), 0, {
        right_gravity = false,
      }),
      direction = direction,
    }
  end

  table.sort(marks, function(left, right)
    local l = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, left.id, {})
    local r = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, right.id, {})
    if l[1] == r[1] then
      return l[2] > r[2]
    end
    return l[1] > r[1]
  end)

  for _, mark in ipairs(marks) do
    local pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.id, {})
    if #pos > 0 then
      local blank_lines = {}
      for _ = 1, count do
        blank_lines[#blank_lines + 1] = ""
      end
      vim.api.nvim_buf_set_lines(buffer, pos[1], pos[1], false, blank_lines)
    end
  end

  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
end

function M.goto_file_targets()
  local pickers = require("axelcool1234.pickers")
  local entries = preview_or_cursor_entries()
  local targets = {}

  if #entries == 1 and not state.preview_active() then
    local detected = vim.fn.expand("<cfile>")
    if detected ~= "" then
      targets[1] = detected
    end
  else
    for _, entry in ipairs(entries) do
      local target = vim.trim(state_module.get_entry_text(entry))
      if target ~= "" then
        targets[#targets + 1] = target
      end
    end
  end

  if #targets == 0 then
    return
  end

  local buffer_name = vim.api.nvim_buf_get_name(0)
  local base_dir = buffer_name ~= "" and vim.fn.fnamemodify(buffer_name, ":p:h") or vim.uv.cwd()

  for _, target in ipairs(targets) do
    if target:match("^%w[%w+.-]*://") then
      vim.ui.open(target)
    else
      local expanded = vim.fn.expand(target)
      local path = vim.fs.normalize(vim.fs.isabspath(expanded) and expanded or vim.fs.joinpath(base_dir, expanded))
      if vim.fn.isdirectory(path) == 1 then
        pickers.find_files_in_directory(path)
      elseif vim.fn.filereadable(path) == 1 then
        vim.cmd.edit(vim.fn.fnameescape(path))
      end
    end
  end
end

local function line_boundary_point(entry, edge)
  local row = entry.cursor_pos[1]
  if edge == "start" then
    return { row, 1 }
  end

  return { row, line_cursor_max_column(row) }
end

local function line_boundary_insert(edge)
  local source_entries = preview_or_cursor_entries()
  local entries = {}
  local history_config = {
    cursor_positions = {},
    preferred_columns = {},
  }

  for index, entry in ipairs(source_entries) do
    entries[index] = point_entry(line_boundary_point(entry, edge))
    history_config.cursor_positions[index] = vim.deepcopy(entries[index].cursor_pos)
    history_config.preferred_columns[index] = entries[index].cursor_pos[2]
  end

  local transaction = history.transaction(entries, history_config)
  if state.preview_active() then
    state.clear_preview({ keep_extend_mode = true })
  end

  insert.start(entries, {
    lifecycle = transaction.lifecycle(false),
  })
end

local function open_line(delta)
  local buffer = vim.api.nvim_get_current_buf()
  local source_entries = preview_or_cursor_entries()
  local transaction = history.transaction(source_entries, current_preview_history_config())
  local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-open-line")
  local marks = {}

  if state.preview_active() then
    state.clear_preview({ keep_extend_mode = true })
  end

  for index, entry in ipairs(source_entries) do
    local insert_row0 = delta > 0 and entry.cursor_pos[1] or entry.cursor_pos[1] - 1
    marks[index] = {
      index = index,
      insert_row0 = insert_row0,
    }
  end

  table.sort(marks, function(left, right)
    if left.insert_row0 == right.insert_row0 then
      return left.index > right.index
    end

    return left.insert_row0 > right.insert_row0
  end)

  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_set_lines(buffer, mark.insert_row0, mark.insert_row0, false, { "" })
    mark.extmark_id = vim.api.nvim_buf_set_extmark(buffer, namespace, mark.insert_row0, 0, {
      right_gravity = false,
    })
  end

  local entries = {}
  for _, mark in ipairs(marks) do
    local pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark.extmark_id, {})
    if #pos > 0 then
      entries[mark.index] = point_entry({ pos[1] + 1, 1 })
    end
  end

  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)

  insert.start(entries, {
    lifecycle = transaction.lifecycle(false),
  })
end

function M.insert_at_line_start()
  line_boundary_insert("start")
end

function M.insert_at_line_end()
  line_boundary_insert("end")
end

function M.open_line_below()
  open_line(1)
end

function M.open_line_above()
  open_line(-1)
end

function M.change_selection(register_name)
  register_name = selected_or_explicit_register(register_name)
  local entries = state.preview_active() and current_preview_entries() or preview_or_cursor_entries()
  if register_name ~= '_' and not store_yanked_entries(entries, register_name) then
    return
  end

  local transaction = history.transaction(entries, current_preview_history_config())
  if state.preview_active() then
    state.clear_preview()
  end

  local start_points = delete_preview_entries(entries)
  sync_cursors_to_points(start_points, { sync_history = false })
  insert.start(state.current_entries(), {
    lifecycle = transaction.lifecycle(true),
  })
end

function M.insert_mode()
  local source_entries = preview_or_cursor_entries()
  local entries, selection_config = insertion_entries_and_selection(source_entries, "start")
  local snapshot_entries, snapshot_config = insert_preview.build_snapshot(entries, selection_config)
  local transaction = history.transaction(snapshot_entries, snapshot_config)
  insert.start(entries, {
    selection = selection_config,
    lifecycle = transaction.lifecycle(false),
  })
end

function M.append_mode()
  local source_entries = preview_or_cursor_entries()
  local entries, selection_config = insertion_entries_and_selection(source_entries, "end")
  local snapshot_entries, snapshot_config = insert_preview.build_snapshot(entries, selection_config)
  local transaction = history.transaction(snapshot_entries, snapshot_config)
  insert.start(entries, {
    selection = selection_config,
    lifecycle = transaction.lifecycle(false),
  })
end

function M.paste_after(register_name)
  register_name = selected_or_explicit_register(register_name)
  local entries = preview_or_cursor_entries()
  local values = registers.read(register_name)
  if #entries == 0 or #values == 0 then
    return
  end

  local count = vim.v.count1
  local repeated = repeated_register_values(values, #entries)
  for index, value in ipairs(repeated) do
    repeated[index] = repeated_text(value, count)
  end

  local points = {}
  for index, entry in ipairs(entries) do
    points[index] = after_entry_point(entry)
  end

  local transaction = history.transaction(entries, current_preview_history_config())
  local updated = insert_points_with_text(points, repeated)
  if #updated > 0 then
    sync_cursors_to_entries(updated, { sync_history = false })
    transaction.commit_now()
  end
end

function M.paste_before(register_name)
  register_name = selected_or_explicit_register(register_name)
  local entries = preview_or_cursor_entries()
  local values = registers.read(register_name)
  if #entries == 0 or #values == 0 then
    return
  end

  local count = vim.v.count1
  local repeated = repeated_register_values(values, #entries)
  for index, value in ipairs(repeated) do
    repeated[index] = repeated_text(value, count)
  end

  local points = {}
  for index, entry in ipairs(entries) do
    points[index] = entry.start_pos
  end

  local transaction = history.transaction(entries, current_preview_history_config())
  local updated = insert_points_with_text(points, repeated)
  if #updated > 0 then
    sync_cursors_to_entries(updated, { sync_history = false })
    transaction.commit_now()
  end
end

function M.yank_selection(register_name)
  register_name = selected_or_explicit_register(register_name)
  if state.preview_active() then
    store_yanked_entries(current_preview_entries(), register_name)
    return
  end

  store_yanked_entries(preview_or_cursor_entries(), register_name)
end

function M.yank_primary_selection(register_name)
  register_name = selected_or_explicit_register(register_name)
  local entry = state.primary_entry()
  if not entry then
    return
  end

  store_yanked_entries({ vim.deepcopy(entry) }, register_name)
end

function M.replace_selection_with_char()
  if state.preview_active() then
    local replacement = getcharstr()
    if not replacement then
      return
    end

    local entries = current_preview_entries()
    local transaction = history.transaction(entries, current_preview_history_config())
    state.clear_preview()
    local updated = replace_preview_entries_with_char(entries, replacement)
    if #updated > 0 then
      sync_cursors_to_entries(updated, { sync_history = false })
    end
    transaction.commit_now()
    return
  end

  local pos = state_module.current_pos_1indexed()
  if pos_is_newline(pos[1], pos[2]) then
    local replacement = getcharstr()
    if not replacement then
      return
    end

    local transaction = history.transaction({ state_module.selection_entry(pos, pos) }, {})
    replace_preview_entries_with_char({ state_module.selection_entry(pos, pos) }, replacement)
    state_module.move_cursor_to_pos(pos)
    transaction.commit_now()
    return
  end

  feedkeys("r", "n")
end

function M.replace_selection_with_yank(register_name)
  register_name = selected_or_explicit_register(register_name)
  local entries = state.preview_active() and current_preview_entries() or preview_or_cursor_entries()
  local transaction = history.transaction(entries, current_preview_history_config())
  local replacements = repeated_register_values(registers.read(register_name), #entries)
  if #replacements == 0 then
    return
  end

  local count = vim.v.count1
  for index, value in ipairs(replacements) do
    replacements[index] = repeated_text(value, count)
  end

  if state.preview_active() then
    state.clear_preview()
  end
  local updated_entries = replace_preview_entries_with_text(entries, replacements)
  sync_cursors_to_entries(updated_entries)
  transaction.commit_now()
end

function M.toggle_selection_case()
  local had_preview = state.preview_active()
  local entries = had_preview and current_preview_entries() or preview_or_cursor_entries()
  local replacements = {}
  local changed = false

  for index, entry in ipairs(entries) do
    local text = state_module.get_entry_text(entry)
    replacements[index] = toggled_case_text(text)
    if replacements[index] ~= text then
      changed = true
    end
  end

  if not changed then
    return
  end

  local transaction = history.transaction(entries, current_preview_history_config())
  replace_preview_entries_with_text(entries, replacements)

  if had_preview then
    set_preview_entries(entries, { sync_history = false })
  else
    state_module.move_cursor_to_pos(entries[1].cursor_pos)
  end

  transaction.commit_now()
end

function M.trim_current_preview_selection()
  if not state.preview_active() then
    return
  end

  local entries = {}
  for _, entry in ipairs(state.preview.entries) do
    local trimmed_start, trimmed_end = compute_trimmed_bounds_from_entry(entry)
    if trimmed_start and trimmed_end then
      table.insert(entries, state_module.selection_entry(trimmed_start, trimmed_end))
    end
  end

  if #entries == 0 then
    state.clear_preview()
    return
  end

  state.set_preview_entries(vim.api.nvim_get_current_buf(), entries)
end

function M.filter_selections_by_regex(keep_matches)
  local pattern = prompt_selection_regex(keep_matches and "keep" or "remove")
  if not pattern or not state.preview_active() then
    return
  end

  local kept = {}
  for _, entry in ipairs(state.preview.entries) do
    local matches = preview_entry_matches(entry, pattern)
    if matches == keep_matches then
      table.insert(kept, entry)
    end
  end

  if #kept == 0 then
    echo_selection_message("no selections remaining")
    return
  end

  state.set_preview_entries(vim.api.nvim_get_current_buf(), kept)
end

function M.select_regex_matches(pattern)
  pattern = pattern and compile_selection_regex(pattern) or prompt_selection_regex("select")
  if not pattern then
    return
  end

  local matches = {}
  for _, entry in ipairs(preview_or_cursor_entries()) do
    vim.list_extend(matches, entry_regex_matches(entry, pattern))
  end

  if #matches == 0 then
    if state.preview_active() then
      state.clear_preview()
    end
    return
  end

  set_preview_entries(matches)
  state.exit_extend_mode()
end

function M.keep_primary_selection_or_cursor()
  if state.preview_active() then
    local first = state.primary_entry()
    state.clear_preview()
    if first then
      state_module.move_cursor_to_pos(first.cursor_pos)
    end
    return
  end

  local entries = preview_or_cursor_entries()
  if #entries <= 1 then
    return
  end

  sync_cursors_to_entries({ state.primary_entry() })
end

function M.flip_selection_direction()
  if not state.preview_active() then
    return
  end

  local flipped = {}
  for _, entry in ipairs(current_preview_entries()) do
    table.insert(flipped, state_module.selection_entry(entry.cursor_pos, entry.anchor_pos))
  end

  set_preview_entries(flipped)
end

function M.ensure_forward_selection_direction()
  local entries = state.preview_active() and current_preview_entries() or preview_or_cursor_entries()
  if #entries == 0 then
    return
  end

  local forward = {}
  for _, entry in ipairs(entries) do
    if entry.anchor_pos[1] > entry.cursor_pos[1]
      or (entry.anchor_pos[1] == entry.cursor_pos[1] and entry.anchor_pos[2] > entry.cursor_pos[2]) then
      table.insert(forward, state_module.selection_entry(entry.cursor_pos, entry.anchor_pos))
    else
      table.insert(forward, entry)
    end
  end

  if state.preview_active() or #forward > 1 then
    set_preview_entries(forward)
  else
    state_module.move_cursor_to_pos(forward[1].cursor_pos)
  end
end

function M.collapse_selections_to_cursors()
  if state.preview_active() then
    local entries = {}
    for _, entry in ipairs(current_preview_entries()) do
      table.insert(entries, point_entry(entry.cursor_pos))
    end
    sync_cursors_to_entries(entries)
    return
  end
end

function M.delete(register_name)
  register_name = selected_or_explicit_register(register_name)
  local entries = preview_or_cursor_entries()
  if register_name ~= '_' and not store_yanked_entries(entries, register_name) then
    return
  end

  if #entries > 1 or state.preview_active() then
    local transaction = history.transaction(entries, current_preview_history_config())
    if state.preview_active() then
      state.clear_preview()
    end
    local start_points = delete_preview_entries(entries)
    sync_cursors_to_points(start_points)
    transaction.commit_now()
    return
  end

  local pos = state_module.current_pos_1indexed()
  local cursor_is_on_newline = pos_is_newline(pos[1], pos[2])
  if cursor_is_on_newline then
    local line = line_text(pos[1])
    vim.api.nvim_buf_set_text(0, pos[1] - 1, #line, pos[1], 0, {})
    state_module.move_cursor_to_pos({ pos[1], #line + 1 })
    return
  end

  vim.cmd("normal! x")
end

function M.select_register(register_name)
  if not register_name then
    register_name = getcharstr()
  end

  if not register_name or register_name == "" then
    vim.on_key(nil, selected_register_clear_ns)
    registers.clear_selected()
    return
  end

  registers.select(register_name)
  arm_selected_register_clear()
  vim.api.nvim_echo({ { string.format('register [%s]', register_name), "ModeMsg" } }, false, {})
end

function M.clear_selected_register()
  vim.on_key(nil, selected_register_clear_ns)
  registers.clear_selected()
end

function M.register_selectable_names()
  return registers.selectable_names()
end

function M.which_key_registers()
  return registers.which_key_entries(function(name)
    M.select_register(name)
  end)
end

local function apply_native_history_jump(command)
  local before_seq = vim.fn.undotree().seq_cur
  local ok = pcall(vim.cmd, command)
  if not ok then
    return
  end

  local after_seq = vim.fn.undotree().seq_cur
  if before_seq == after_seq then
    return
  end

  if not history.restore_after_jump(after_seq) and state.preview_active() then
    state.clear_preview()
  end
end

function M.undo()
  if history.can_navigate_current_seq(-1) and history.undo_snapshot() then
    return
  end

  apply_native_history_jump("undo")
end

function M.redo()
  if history.can_navigate_current_seq(1) and history.redo_snapshot() then
    return
  end

  apply_native_history_jump("redo")
end

function M.surround_add()
  match.surround_add()
end

function M.surround_delete()
  match.surround_delete()
end

function M.surround_replace()
  match.surround_replace()
end

function M.surround_delete_nearest()
  match.surround_delete_nearest()
end

function M.select_around_pair()
  match.select_around_pair()
end

function M.select_inside_pair()
  match.select_inside_pair()
end

function M.goto_match()
  match.goto_match()
end

function M.extend_line_below()
  local last_row = position.line_count(current_buffer())
  local entries = {}

  for _, entry in ipairs(preview_or_cursor_entries()) do
    if state.extend_mode_active() then
      local extra_rows = entry_is_full_line(entry) and vim.v.count1 or (vim.v.count1 - 1)
      local end_row = math.min(entry.end_pos[1] + extra_rows, last_row)
      table.insert(entries, linewise_entry_from_entry(entry, end_row))
    elseif state.preview_active() then
      local extra_rows = entry_is_full_line(entry) and vim.v.count1 or (vim.v.count1 - 1)
      local end_row = math.min(entry.end_pos[1] + extra_rows, last_row)
      table.insert(entries, full_line_entry(entry.start_pos[1], end_row))
    else
      table.insert(entries, full_line_entry(entry.cursor_pos[1]))
    end
  end

  set_preview_entries(entries)
  if not state.extend_mode_active() then
    state.exit_extend_mode()
  end
end

local function shift_linewise(direction)
  local buffer = current_buffer()
  local source_entries = state.preview_active() and current_preview_entries() or preview_or_cursor_entries()
  local line_entries = linewise_entries(source_entries)
  local transaction = history.transaction(source_entries, current_preview_history_config())
  local count = vim.v.count1
  local command = direction == "right" and ">" or "<"
  local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-shift-linewise")
  local marks = create_entry_marks(buffer, source_entries, namespace)
  local ranges = merged_line_ranges(line_entries)
  local had_preview = state.preview_active()

  if had_preview then
    state.clear_preview({ keep_extend_mode = true })
  end

  for _ = 1, count do
    for index = #ranges, 1, -1 do
      local range = ranges[index]
      state_module.move_cursor_to_pos({ range.start_row, 1 })
      local line_count = range.end_row - range.start_row + 1
      vim.cmd("normal! " .. line_count .. command .. command)
    end
  end

  local updated = restore_entries_from_marks(buffer, source_entries, namespace, marks)
  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)

  if had_preview or #updated > 1 then
    state.set_preview_entries(buffer, updated, { sync_history = false })
  else
    if state.preview_active() then
      state.clear_preview({ keep_extend_mode = true })
    end
    state_module.move_cursor_to_pos(updated[1].cursor_pos)
  end

  state.exit_extend_mode()
  transaction.commit_now()
end

function M.shift_right()
  shift_linewise("right")
end

function M.shift_left()
  shift_linewise("left")
end

function M.select_whole_buffer()
  local buffer = vim.api.nvim_get_current_buf()
  local last_row = vim.fn.line("$")
  local last_col = line_cursor_max_column(last_row)
  local keep_select_mode = state.extend_mode_active()

  local entries = {}
  for _ = 1, #preview_or_cursor_entries() do
    table.insert(entries, state_module.selection_entry({ 1, 1 }, { last_row, last_col }))
  end

  state.set_preview_entries(buffer, entries)
  if not keep_select_mode then
    state.exit_extend_mode()
  end
end

function M.copy_selection_on_adjacent_line(delta)
  local source_entries = state.preview_active() and current_preview_entries() or preview_or_cursor_entries()
  local source_preferred_columns = state.current_preferred_columns()
  local combined_entries = {}
  local combined_preferred_columns = {}

  local function append_entry(entry, preferred_col)
    table.insert(combined_entries, entry)
    table.insert(combined_preferred_columns, preferred_col or entry.cursor_pos[2])
  end

  local primary_clone = clone_entry_to_supported_line(source_entries[1], delta, source_preferred_columns[1])

  if not primary_clone then
    return
  end

  append_entry(primary_clone, source_preferred_columns[1])

  for index, entry in ipairs(source_entries) do
    append_entry(vim.deepcopy(entry), source_preferred_columns[index])
  end

  for index = 2, #source_entries do
    local clone = clone_entry_to_supported_line(source_entries[index], delta, source_preferred_columns[index])
    if clone then
      append_entry(clone, source_preferred_columns[index])
    end
  end

  if state.preview_active() then
    set_preview_entries(combined_entries, { preferred_columns = combined_preferred_columns })
    return
  end

  sync_cursors_to_entries(combined_entries, { preferred_columns = combined_preferred_columns })
end

function M.split_selection_by_line()
  if not state.preview_active() then
    return
  end

  local entries = {}
  for _, entry in ipairs(current_preview_entries()) do
    for _, segment in ipairs(selection_segments_by_line(entry)) do
      table.insert(entries, segment)
    end
  end

  set_preview_entries(entries)
end

function M.toggle_select_mode()
  local buffer = vim.api.nvim_get_current_buf()

  if state.extend_mode_active() then
    state.exit_extend_mode()
    return
  end

  state.enter_extend_mode()

  if state.preview_active() then
    state.set_preview_entries(buffer, current_preview_entries(), { keep_cursor = true })
    return
  end

  state.set_preview_entries(buffer, state.current_entries(), { keep_cursor = true })
end

function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("axelcool1234-helix-preview", { clear = true })

  local function track_modified_buffer(args)
    local buf = args.buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    for index, existing in ipairs(last_modified_buffers) do
      if existing == buf then
        table.remove(last_modified_buffers, index)
        break
      end
    end
    table.insert(last_modified_buffers, 1, buf)
  end

  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function()
      if state.preview.buffer and not state.preview.updating then
        state.clear_preview()
      end
    end,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      if state.preview.buffer and not state.preview.updating and not state.insert_mode_active() then
        state.clear_preview()
      end
    end,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    callback = function()
      if state.consume_pending_escape() then
        return
      end

      if state.preview.buffer and not state.preview.updating and not state.extend_mode_active() then
        state.clear_preview()
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      history.clear_buffer(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = track_modified_buffer,
  })
end

return M
