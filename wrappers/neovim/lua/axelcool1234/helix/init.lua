local state_module = require("axelcool1234.helix.state")
local motion_module = require("axelcool1234.helix.motion")
local insert_module = require("axelcool1234.helix.insert")
local history_module = require("axelcool1234.helix.history")
local insert_preview_module = require("axelcool1234.helix.insert_preview")
local registers_module = require("axelcool1234.helix.registers")
local match_module = require("axelcool1234.helix.match")
local flash_module = require("axelcool1234.helix.flash")
local window_module = require("axelcool1234.helix.window")
local position = require("axelcool1234.helix.position")

local M = {}
local selected_register_clear_ns = vim.api.nvim_create_namespace("axelcool1234-helix-selected-register")
local macro_transport_register = "z"

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

local flash = flash_module.new({
  position = position,
  getcharstr = getcharstr,
})

local window = window_module.new()

local last_modified_buffers = {}
local last_repeatable_motion = nil
local replaying_last_motion = false
local macro_recording_target = nil
local macro_recording_saved = nil
local macro_replaying = {}
local incremental_search = {
  active = nil,
  ignore_cursor_moved = 0,
}

history.attach()

local current_buffer
local line_text
local line_cursor_max_column
local line_supports_column
local pos_is_newline
local extmark_pos_1indexed

local function entry_ends_after(left, right)
  if left.end_pos[1] == right.end_pos[1] then
    return left.end_pos[2] > right.end_pos[2]
  end
  return left.end_pos[1] > right.end_pos[1]
end

local replacement_lines

local function remember_repeatable_motion(replay)
  if replaying_last_motion then
    return
  end

  last_repeatable_motion = replay
end

local function save_vim_register(name)
  return {
    contents = vim.fn.getreg(name, 1, true),
    regtype = vim.fn.getregtype(name),
  }
end

local function macro_native_register(target)
  if target and target:match("^[%w]$") then
    return target
  end

  return macro_transport_register
end

local function restore_vim_register(name, saved)
  if not saved then
    return
  end
  vim.fn.setreg(name, saved.contents, saved.regtype)
end

local function update_selected_register_indicator(register_name)
  vim.g.helix_selected_register = register_name
  refresh_lualine()
end

local function update_macro_recording_indicator(register_name)
  vim.g.helix_macro_recording_register = register_name
  refresh_lualine()
end

local function clear_selected_register_indicator()
  registers.clear_selected()
  update_selected_register_indicator(nil)
end

local function arm_selected_register_clear()
  vim.on_key(nil, selected_register_clear_ns)
  vim.on_key(function()
    vim.on_key(nil, selected_register_clear_ns)
    vim.schedule(function()
      clear_selected_register_indicator()
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
    local start_pos = extmark_pos_1indexed(buffer, namespace, mark.start_id)
    if start_pos then
      start_points[mark.index] = start_pos
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
      return { start_pos[1], start_pos[2] + position.char_count(lines[1]) - 1 }
    end

    return { start_pos[1] + #lines - 1, position.char_count(lines[#lines]) }
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
    local start_1indexed = extmark_pos_1indexed(buffer, namespace, mark.start_id)
    if start_1indexed then
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

local function text_cell_at_pos(pos)
  if pos_is_newline(pos[1], pos[2]) then
    return "\n"
  end

  local line = line_text(pos[1])
  if pos[2] > position.char_count(line) then
    return nil
  end

  return position.char_at(line, pos[2])
end

local function char_is_word(ch)
  return ch ~= nil and ch ~= "\n" and ch:match("[%w_]") ~= nil
end

local function selection_search_fragment(entry, detect_word_boundaries)
  local text = state_module.get_entry_text(entry)
  if text == "" then
    return nil
  end

  local escaped = text:gsub("\\", "\\\\")
  escaped = escaped:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?%{%}%|<>])", "\\%1")
  escaped = escaped:gsub("\n", "\\n")

  if not detect_word_boundaries then
    return escaped
  end

  local buffer = current_buffer()
  local start_char = text_cell_at_pos(entry.start_pos)
  local end_char = text_cell_at_pos(entry.end_pos)
  local prev_pos = position.prev_pos(buffer, entry.start_pos)
  local next_pos = position.next_pos(buffer, entry.end_pos)
  local prev_char = nil
  local next_char = nil
  if not (prev_pos[1] == entry.start_pos[1] and prev_pos[2] == entry.start_pos[2]) then
    prev_char = text_cell_at_pos(prev_pos)
  end
  if not (next_pos[1] == entry.end_pos[1] and next_pos[2] == entry.end_pos[2]) then
    next_char = text_cell_at_pos(next_pos)
  end

  if char_is_word(start_char) and not char_is_word(prev_char) then
    escaped = "<" .. escaped
  end

  if char_is_word(end_char) and not char_is_word(next_char) then
    escaped = escaped .. ">"
  end

  return escaped
end

local function get_preview_lines(entry)
  local lines = vim.api.nvim_buf_get_lines(0, entry.start_pos[1] - 1, entry.end_pos[1], false)
  if #lines == 0 then
    return {}
  end

  lines[1] = position.suffix_from_char_col(lines[1], entry.start_pos[2])
  lines[#lines] = position.slice_by_char_range(lines[#lines], 1, entry.end_pos[2])
  return lines
end

local function find_trimmed_edge(entry, forward)
  local buffer = current_buffer()
  local pos = vim.deepcopy(forward and entry.start_pos or entry.end_pos)
  local limit = forward and entry.end_pos or entry.start_pos

  while true do
    local cell = text_cell_at_pos(pos)
    if cell and not cell:match("%s") then
      return pos
    end

    if pos[1] == limit[1] and pos[2] == limit[2] then
      return nil
    end

    pos = forward and position.next_pos(buffer, pos) or position.prev_pos(buffer, pos)
  end
end

local function compute_trimmed_bounds_from_entry(entry)
  local trimmed_start = find_trimmed_edge(entry, true)
  local trimmed_end = find_trimmed_edge(entry, false)

  if not trimmed_start or not trimmed_end then
    return nil
  end

  return trimmed_start, trimmed_end
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

local function suspend_incremental_search_cursor_clear(count)
  incremental_search.ignore_cursor_moved = math.max(incremental_search.ignore_cursor_moved, count or 1)
end

local function validate_selection_regex(pattern)
  local compiled = compile_selection_regex(pattern)
  match_lines({ "" }, compiled)
  return compiled
end

local function prompt_selection_regex(prompt, register_name)
  local pattern = vim.fn.input(prompt .. ": ")
  if pattern == "" then
    return nil
  end

  local ok, err = pcall(function()
    validate_selection_regex(pattern)
  end)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end

  return pattern
end

local function bytecol_to_charcol(row, bytecol)
  local line = line_text(row)
  return position.char_col_from_byte_col0(line, math.max(bytecol - 1, 0))
end

local function first_register_value(register_name)
  local values = registers.read(register_name)
  return values[1]
end

local function resolve_search_register(default_register)
  return registers.take_selected() or default_register or registers.last_search_register()
end

local function set_search_register(register_name, pattern)
  local ok, err = registers.write(register_name, { pattern })
  if not ok then
    if err then
      vim.notify(err, vim.log.levels.ERROR)
    end
    return false
  end

  registers.set_last_search_register(register_name)
  return true
end

local function compiled_search_pattern(register_name)
  local pattern = first_register_value(register_name)
  if not pattern then
    return nil
  end

  return compile_selection_regex(pattern)
end

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

local function apply_search_match(pattern, direction, config)
  config = config or {}

  local source_entries = config.source_entries or (state.preview_active() and current_preview_entries() or state.current_entries())
  local had_preview = config.had_preview
  if had_preview == nil then
    had_preview = state.preview_active()
  end
  local extend_mode = config.extend_mode
  if extend_mode == nil then
    extend_mode = state.extend_mode_active()
  end
  local match_entry = search_match_entry(source_entries[1], pattern, direction)
  if not match_entry then
    if config.no_message ~= true then
      vim.api.nvim_echo({ { "no more matches", "WarningMsg" } }, false, {})
    end
    return false
  end

  local entries = { match_entry }

  if extend_mode then
    for _, entry in ipairs(source_entries) do
      table.insert(entries, entry)
    end
    state.set_preview_entries(current_buffer(), entries, {
      sync_history = config.sync_history,
    })
    return true
  end

  if had_preview and #source_entries > 1 then
    for index = 2, #source_entries do
      table.insert(entries, source_entries[index])
    end
  end

  state.set_preview_entries(current_buffer(), entries, {
    sync_history = config.sync_history,
  })
  state.exit_extend_mode()
  return true
end

local function restore_search_snapshot(session)
  if not session then
    return
  end

  suspend_incremental_search_cursor_clear(2)
  state.clear_preview({ keep_extend_mode = true, keep_insert_mode = true })
  if session.extend_mode then
    state.enter_extend_mode()
  else
    state.exit_extend_mode()
  end

  if session.had_preview then
    state.set_preview_entries(session.buffer, vim.deepcopy(session.entries), {
      sync_history = false,
    })
  else
    state_module.move_cursor_to_pos(session.cursor_pos)
  end

  vim.fn.winrestview(session.view)
  vim.cmd.nohlsearch()
end

local function apply_incremental_search(session, pattern, notify_errors, sync_history)
  if not session then
    return false
  end

  restore_search_snapshot(session)
  if pattern == "" then
    return true
  end

  local ok, compiled_or_err = pcall(validate_selection_regex, pattern)
  if not ok then
    if notify_errors then
      vim.notify(compiled_or_err, vim.log.levels.ERROR)
    end
    restore_search_snapshot(session)
    return false
  end

  local ok_apply, matched = pcall(apply_search_match, compiled_or_err, session.direction, {
    extend_mode = session.extend_mode,
    had_preview = session.had_preview,
    no_message = true,
    source_entries = vim.deepcopy(session.entries),
    sync_history = sync_history,
  })

  if not ok_apply then
    if notify_errors then
      vim.notify(matched, vim.log.levels.ERROR)
    end
    restore_search_snapshot(session)
    return false
  end

  if not matched then
    restore_search_snapshot(session)
    return false
  end

  return true
end

local function finish_incremental_search(session, confirmed)
  incremental_search.active = nil
  vim.o.incsearch = session.saved_incsearch
  restore_vim_register("/", session.saved_search_register)

  if not confirmed or session.pattern == "" then
    restore_search_snapshot(session)
    return
  end

  if not set_search_register(session.register_name, session.pattern) then
    restore_search_snapshot(session)
    return
  end

  vim.fn.setreg("/", session.pattern, "v")
  vim.fn.histadd("search", session.pattern)
  vim.cmd.nohlsearch()

  if not apply_incremental_search(session, session.pattern, true, nil) then
    return
  end

  suspend_incremental_search_cursor_clear(2)
  vim.schedule(function()
    if state.preview_active() then
      state.refresh_preview()
    end
    vim.cmd.nohlsearch()
  end)
end

local incremental_search_group = vim.api.nvim_create_augroup("axelcool1234-helix-incremental-search", { clear = true })

vim.api.nvim_create_autocmd("CmdlineChanged", {
  group = incremental_search_group,
  callback = function()
    local session = incremental_search.active
    if not session or vim.fn.getcmdtype() ~= session.cmdtype then
      return
    end

    session.pattern = vim.fn.getcmdline()
    apply_incremental_search(session, session.pattern, false, false)
  end,
})

vim.api.nvim_create_autocmd("CmdlineLeavePre", {
  group = incremental_search_group,
  callback = function()
    local session = incremental_search.active
    if not session or vim.fn.getcmdtype() ~= session.cmdtype then
      return
    end

    session.pattern = vim.fn.getcmdline()
  end,
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = incremental_search_group,
  callback = function()
    local session = incremental_search.active
    if not session or vim.v.event.cmdtype ~= session.cmdtype then
      return
    end

    local confirmed = not vim.v.event.abort

    if confirmed then
      vim.v.event.abort = true
    end

    vim.schedule(function()
      finish_incremental_search(session, confirmed)
    end)
  end,
})

local function start_incremental_search(direction)
  local cmdtype = direction == "backward" and "?" or "/"
  local register_name = resolve_search_register('/')
  local source_entries = state.preview_active() and current_preview_entries() or state.current_entries()

  incremental_search.active = {
    buffer = current_buffer(),
    cmdtype = cmdtype,
    cursor_pos = state_module.current_pos_1indexed(),
    direction = direction,
    entries = vim.deepcopy(source_entries),
    extend_mode = state.extend_mode_active(),
    had_preview = state.preview_active(),
    pattern = "",
    register_name = register_name,
    saved_incsearch = vim.o.incsearch,
    saved_search_register = save_vim_register("/"),
    view = vim.fn.winsaveview(),
  }

  vim.o.incsearch = false
  feedkeys(cmdtype, "n")
end

function M.search_regex()
  start_incremental_search("forward")
end

function M.search_regex_backward()
  start_incremental_search("backward")
end

function M.search_next(direction)
  direction = direction or "forward"
  local register_name = resolve_search_register(registers.last_search_register())
  local pattern = compiled_search_pattern(register_name)
  if not pattern then
    vim.api.nvim_echo({ { "no previous search", "WarningMsg" } }, false, {})
    return
  end

  apply_search_match(pattern, direction)
end

local function echo_search_register_set(register_name, pattern)
  vim.api.nvim_echo({ { string.format("register '%s' set to '%s'", register_name, pattern), "ModeMsg" } }, false, {})
end

local function search_selection_impl(detect_word_boundaries)
  local register_name = resolve_search_register('/')
  local source_entries = state.current_entries()
  local fragments = {}
  local seen = {}

  for _, entry in ipairs(source_entries) do
    local fragment = selection_search_fragment(entry, detect_word_boundaries)
    if fragment and not seen[fragment] then
      seen[fragment] = true
      fragments[#fragments + 1] = fragment
    end
  end

  if #fragments == 0 then
    return
  end

  local pattern = table.concat(fragments, "|")
  if set_search_register(register_name, pattern) then
    echo_search_register_set(register_name, pattern)
  end
end

function M.search_selection()
  search_selection_impl(false)
end

function M.search_selection_detect_word_boundaries()
  search_selection_impl(true)
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
    local start_char = position.char_col_from_byte_col0(lines[match.idx + 1], match.byteidx)
    local start_col = match.idx == 0 and (entry.start_pos[2] + start_char - 1) or start_char
    local width = math.max(position.char_count(match.text), 1)
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

local function reverse_concat(parts)
  local out = {}
  for index = #parts, 1, -1 do
    out[#out + 1] = parts[index]
  end
  return table.concat(out)
end

local function trim_leading_zeros(text)
  local trimmed = text:gsub("^0+", "")
  return trimmed == "" and "0" or trimmed
end

local function char_value(char)
  local byte = string.byte(char)
  if not byte then
    return nil
  end

  if byte >= string.byte("0") and byte <= string.byte("9") then
    return byte - string.byte("0")
  end

  local lower = string.lower(char)
  local lower_byte = string.byte(lower)
  if lower_byte >= string.byte("a") and lower_byte <= string.byte("f") then
    return lower_byte - string.byte("a") + 10
  end

  return nil
end

local function digit_char(value, uppercase)
  if value < 10 then
    return string.char(string.byte("0") + value)
  end

  return string.char((uppercase and string.byte("A") or string.byte("a")) + value - 10)
end

local function valid_digits(text, radix)
  if text == "" then
    return false
  end

  for index = 1, #text do
    local value = char_value(text:sub(index, index))
    if not value or value >= radix then
      return false
    end
  end

  return true
end

local function compare_unsigned(left, right)
  left = trim_leading_zeros(left)
  right = trim_leading_zeros(right)
  if #left ~= #right then
    return #left < #right and -1 or 1
  end
  if left == right then
    return 0
  end
  return left < right and -1 or 1
end

local function add_unsigned(left, right, radix)
  local carry = 0
  local parts = {}
  local li = #left
  local ri = #right

  while li > 0 or ri > 0 or carry > 0 do
    local lv = li > 0 and char_value(left:sub(li, li)) or 0
    local rv = ri > 0 and char_value(right:sub(ri, ri)) or 0
    local total = lv + rv + carry
    parts[#parts + 1] = digit_char(total % radix, false)
    carry = math.floor(total / radix)
    li = li - 1
    ri = ri - 1
  end

  return reverse_concat(parts)
end

local function sub_unsigned(left, right, radix)
  local borrow = 0
  local parts = {}
  local li = #left
  local ri = #right

  while li > 0 do
    local lv = char_value(left:sub(li, li)) - borrow
    local rv = ri > 0 and char_value(right:sub(ri, ri)) or 0
    if lv < rv then
      lv = lv + radix
      borrow = 1
    else
      borrow = 0
    end
    parts[#parts + 1] = digit_char(lv - rv, false)
    li = li - 1
    ri = ri - 1
  end

  return trim_leading_zeros(reverse_concat(parts))
end

local function int_to_base(value, radix)
  if value == 0 then
    return "0"
  end

  local parts = {}
  while value > 0 do
    parts[#parts + 1] = digit_char(value % radix, false)
    value = math.floor(value / radix)
  end

  return reverse_concat(parts)
end

local function pad_signed_decimal(is_negative, digits, width)
  local sign_width = is_negative and 1 or 0
  local zeros = math.max(width - sign_width - #digits, 0)
  return (is_negative and "-" or "") .. string.rep("0", zeros) .. digits
end

local function restore_integer_separators(original_text, new_text, radix, separator_rtl_indexes)
  for _, rtl_index in ipairs(separator_rtl_indexes) do
    if rtl_index < #new_text then
      local insert_at = #new_text - rtl_index
      if insert_at > 0 then
        new_text = new_text:sub(1, insert_at) .. "_" .. new_text:sub(insert_at + 1)
      end
    end
  end

  if #new_text > #original_text and #separator_rtl_indexes > 0 then
    local spacing = #separator_rtl_indexes >= 2
        and (separator_rtl_indexes[#separator_rtl_indexes] - separator_rtl_indexes[#separator_rtl_indexes - 1] - 1)
      or separator_rtl_indexes[1]
    local prefix_length = radix == 10 and 0 or 2
    local first_separator = new_text:find("_", 1, true)
    if first_separator then
      local insert_at = first_separator - 1
      while insert_at - prefix_length > spacing do
        insert_at = insert_at - spacing
        new_text = new_text:sub(1, insert_at) .. "_" .. new_text:sub(insert_at + 1)
      end
    end
  end

  return new_text
end

local function increment_integer_text(selected_text, amount)
  if selected_text == "" or selected_text:sub(1, 1) == "_" or selected_text:sub(-1) == "_" then
    return nil
  end

  local radix = selected_text:sub(1, 2) == "0x" and 16
    or selected_text:sub(1, 2) == "0o" and 8
    or selected_text:sub(1, 2) == "0b" and 2
    or 10
  local separator_rtl_indexes = {}
  for index = #selected_text, 1, -1 do
    if selected_text:sub(index, index) == "_" then
      separator_rtl_indexes[#separator_rtl_indexes + 1] = #selected_text - index
    end
  end

  local word = selected_text:gsub("_", "")
  local new_text

  if radix == 10 then
    local negative = word:sub(1, 1) == "-"
    local digits = negative and word:sub(2) or word
    if not valid_digits(digits, radix) then
      return nil
    end

    local amount_abs = math.abs(amount)
    local amount_digits = tostring(amount_abs)
    local result_negative
    local result_digits

    if negative then
      if amount >= 0 then
        local cmp = compare_unsigned(digits, amount_digits)
        if cmp > 0 then
          result_negative = true
          result_digits = sub_unsigned(digits, amount_digits, radix)
        elseif cmp == 0 then
          result_negative = false
          result_digits = "0"
        else
          result_negative = false
          result_digits = sub_unsigned(amount_digits, digits, radix)
        end
      else
        result_negative = true
        result_digits = add_unsigned(digits, amount_digits, radix)
      end
    else
      if amount >= 0 then
        result_negative = false
        result_digits = add_unsigned(digits, amount_digits, radix)
      else
        local cmp = compare_unsigned(digits, amount_digits)
        if cmp > 0 then
          result_negative = false
          result_digits = sub_unsigned(digits, amount_digits, radix)
        elseif cmp == 0 then
          result_negative = false
          result_digits = "0"
        else
          result_negative = true
          result_digits = sub_unsigned(amount_digits, digits, radix)
        end
      end
    end

    local format_length = #word - #separator_rtl_indexes
    if negative and not result_negative then
      format_length = format_length - 1
    elseif not negative and result_negative then
      format_length = format_length + 1
    end

    if word:sub(1, 1) == "0" or word:sub(1, 2) == "-0" then
      new_text = pad_signed_decimal(result_negative, result_digits, format_length)
    else
      new_text = (result_negative and "-" or "") .. result_digits
    end
  else
    local digits = word:sub(3)
    if not valid_digits(digits, radix) then
      return nil
    end

    local result_digits
    if amount >= 0 then
      result_digits = add_unsigned(digits, int_to_base(amount, radix), radix)
    else
      local amount_digits = int_to_base(-amount, radix)
      if compare_unsigned(digits, amount_digits) <= 0 then
        result_digits = "0"
      else
        result_digits = sub_unsigned(digits, amount_digits, radix)
      end
    end

    local format_length = #selected_text - 2 - #separator_rtl_indexes
    if #result_digits < format_length then
      result_digits = string.rep("0", format_length - #result_digits) .. result_digits
    end

    if radix == 16 then
      local lower_count = 0
      local upper_count = 0
      for index = 1, #digits do
        local char = digits:sub(index, index)
        lower_count = lower_count + (char:match("%l") and 1 or 0)
        upper_count = upper_count + (char:match("%u") and 1 or 0)
      end
      if upper_count > lower_count then
        result_digits = string.upper(result_digits)
      end
    end

    new_text = word:sub(1, 2) .. result_digits
  end

  return restore_integer_separators(selected_text, new_text, radix, separator_rtl_indexes)
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

local full_line_entry

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
    local start_1indexed = extmark_pos_1indexed(buffer, namespace, mark.start_id)
    local end_1indexed = extmark_pos_1indexed(buffer, namespace, mark.end_id)
    if start_1indexed and end_1indexed then
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

local function register_values_are_linewise(values)
  for _, value in ipairs(values) do
    if value:match("\r\n$") or value:match("\n$") or value:match("\r$") then
      return true
    end
  end

  return false
end

local function split_linewise_replacement(text)
  local normalized = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  normalized = normalized:gsub("\n$", "")

  if normalized == "" then
    return { "" }
  end

  return vim.split(normalized, "\n", { plain = true })
end

local function insert_linewise_rows_with_text(target_rows, replacements)
  if #target_rows == 0 or #replacements == 0 then
    return {}
  end

  local buffer = vim.api.nvim_get_current_buf()
  local inserts = {}

  for index, target_row in ipairs(target_rows) do
    inserts[index] = {
      index = index,
      target_row = target_row,
      lines = split_linewise_replacement(replacements[index]),
    }
  end

  table.sort(inserts, function(left, right)
    if left.target_row == right.target_row then
      return left.index > right.index
    end

    return left.target_row > right.target_row
  end)

  local updated = {}
  for _, insert in ipairs(inserts) do
    local row0 = math.min(insert.target_row - 1, vim.api.nvim_buf_line_count(buffer))
    vim.api.nvim_buf_set_lines(buffer, row0, row0, false, insert.lines)

    local start_row = row0 + 1
    local end_row = start_row + #insert.lines - 1
    updated[insert.index] = full_line_entry(start_row, end_row)
  end

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

local function capture_selection_state_snapshot()
  return {
    cursor_pos = state_module.current_pos_1indexed(),
    entries = preview_or_cursor_entries(),
    extend_mode = state.extend_mode_active(),
    had_preview = state.preview_active(),
    primary_entry = vim.deepcopy(state.primary_entry()),
  }
end

local function restore_selection_state_snapshot(snapshot)
  if not snapshot then
    return
  end

  state.clear_preview({ keep_insert_mode = true })
  if snapshot.extend_mode then
    state.enter_extend_mode()
  else
    state.exit_extend_mode()
  end

  local needs_preview = snapshot.had_preview or snapshot.extend_mode or #snapshot.entries > 1
  if needs_preview then
    state.set_preview_entries(current_buffer(), vim.deepcopy(snapshot.entries), { sync_history = false })
    if not snapshot.extend_mode then
      state.exit_extend_mode()
    end
    return
  end

  state_module.move_cursor_to_pos(snapshot.cursor_pos)
end

local function collapse_to_primary_for_flash(snapshot)
  if not snapshot or not snapshot.primary_entry then
    return
  end

  if snapshot.extend_mode then
    state.enter_extend_mode()
    state.set_preview_entries(current_buffer(), { vim.deepcopy(snapshot.primary_entry) }, { sync_history = false })
    return
  end

  state.clear_preview({ keep_insert_mode = true })
  state.exit_extend_mode()
  state_module.move_cursor_to_pos(snapshot.primary_entry.cursor_pos)
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

local function echo_yank_status(count, register_name)
  local selection_label = count == 1 and "selection" or "selections"
  local resolved_register = register_name or '"'
  vim.api.nvim_echo({ { string.format("yanked %d %s to register %s", count, selection_label, resolved_register), "ModeMsg" } }, false, {})
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
      return { start_pos[1], start_pos[2] + position.char_count(lines[1]) - 1 }
    end

    return { start_pos[1] + #lines - 1, position.char_count(lines[#lines]) }
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
    local start_1indexed = extmark_pos_1indexed(buffer, namespace, mark.start_id)
    if start_1indexed then
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

full_line_entry = function(row_start, row_end)
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

extmark_pos_1indexed = function(buffer, namespace, mark_id)
  local pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark_id, {})
  if #pos == 0 then
    return nil
  end

  local row = pos[1] + 1
  return { row, position.char_col_from_byte_col0(position.line_text(buffer, row), pos[2]) }
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

local function insert_around_entries_preserving_selections(entries, points, replacements)
  if #entries == 0 or #points == 0 or #replacements == 0 then
    return {}
  end

  local buffer = vim.api.nvim_get_current_buf()
  local namespace = vim.api.nvim_create_namespace("axelcool1234-paste-restore-selection")
  local marks = create_entry_marks(buffer, entries, namespace)

  insert_points_with_text(points, replacements)
  local restored = restore_entries_from_marks(buffer, entries, namespace, marks)

  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
  return restored
end

local function insert_linewise_rows_preserving_selections(entries, target_rows, replacements)
  if #entries == 0 or #target_rows == 0 or #replacements == 0 then
    return {}
  end

  local buffer = vim.api.nvim_get_current_buf()
  local namespace = vim.api.nvim_create_namespace("axelcool1234-paste-linewise-restore-selection")
  local marks = create_entry_marks(buffer, entries, namespace)

  insert_linewise_rows_with_text(target_rows, replacements)
  local restored = restore_entries_from_marks(buffer, entries, namespace, marks)

  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
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

local function line_indent_and_content(line)
  local indent = line:match("^%s*") or ""
  return indent, line:sub(#indent + 1)
end

local function parse_commentstring(commentstring)
  if type(commentstring) ~= "string" or commentstring == "" then
    return nil
  end

  local marker = commentstring:find("%%s", 1, false)
  if not marker then
    return nil
  end

  return commentstring:sub(1, marker - 1), commentstring:sub(marker + 2)
end

local function parse_block_comment_tokens(comments)
  if type(comments) ~= "string" or comments == "" then
    return nil
  end

  local start_token = nil
  for _, part in ipairs(vim.split(comments, ",", { plain = true, trimempty = true })) do
    local flags, text = part:match("^([^:]+):(.*)$")
    if flags and text then
      if flags:sub(1, 1) == "s" then
        start_token = text
      elseif start_token and flags:sub(1, 2) == "ex" then
        return start_token, text
      end
    end
  end

  return nil
end

local function entry_pos_equal(left, right)
  return left[1] == right[1] and left[2] == right[2]
end

local function create_directional_entry_marks(buffer, entries, namespace)
  local marks = {}
  for index, entry in ipairs(entries) do
    local anchor_row, anchor_col = position.before_boundary(buffer, entry.anchor_pos)
    local cursor_row, cursor_col = position.before_boundary(buffer, entry.cursor_pos)
    marks[index] = {
      anchor_id = vim.api.nvim_buf_set_extmark(buffer, namespace, anchor_row, anchor_col, {
        right_gravity = entry_pos_equal(entry.anchor_pos, entry.start_pos),
      }),
      cursor_id = vim.api.nvim_buf_set_extmark(buffer, namespace, cursor_row, cursor_col, {
        right_gravity = entry_pos_equal(entry.cursor_pos, entry.start_pos),
      }),
    }
  end

  return marks
end

local function line_is_commented(line, prefix, suffix)
  local _, content = line_indent_and_content(line)
  if content == "" then
    return true
  end

  if content:sub(1, #prefix) ~= prefix then
    return false
  end

  if suffix == "" then
    return true
  end

  return #content >= (#prefix + #suffix) and content:sub(-#suffix) == suffix
end

local function toggle_comments_for_entries(entries)
  if #entries == 0 then
    return false
  end

  local prefix, suffix = parse_commentstring(vim.bo.commentstring)
  if not prefix then
    vim.notify("commentstring is not available in current buffer", vim.log.levels.WARN)
    return false
  end

  local ranges = merged_line_ranges(entries)
  if #ranges == 0 then
    return false
  end

  local all_commented = true
  local has_nonblank = false
  local line_infos = {}
  for _, range in ipairs(ranges) do
    for row = range.start_row, range.end_row do
      local line = line_text(row)
      local indent, content = line_indent_and_content(line)
      line_infos[row] = {
        line = line,
        indent = indent,
        content = content,
      }
      if content ~= "" then
        has_nonblank = true
        if not line_is_commented(line, prefix, suffix) then
          all_commented = false
        end
      end
    end
  end

  local buffer = current_buffer()
  local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-toggle-comments")
  local marks = create_entry_marks(buffer, entries, namespace)
  local edits = {}

  for _, range in ipairs(ranges) do
    for row = range.start_row, range.end_row do
      local info = line_infos[row]
      if info and info.content ~= "" then
        local indent_len = #info.indent
        local line_len = #info.line
        if all_commented then
          edits[#edits + 1] = {
            row = row,
            start_col = indent_len,
            end_col = indent_len + #prefix,
            replacement = {},
          }
          if suffix ~= "" then
            edits[#edits + 1] = {
              row = row,
              start_col = line_len - #suffix,
              end_col = line_len,
              replacement = {},
            }
          end
        else
          edits[#edits + 1] = {
            row = row,
            start_col = indent_len,
            end_col = indent_len,
            replacement = { prefix },
          }
          if suffix ~= "" then
            edits[#edits + 1] = {
              row = row,
              start_col = line_len,
              end_col = line_len,
              replacement = { suffix },
            }
          end
        end
      end
    end
  end

  table.sort(edits, function(left, right)
    if left.row == right.row then
      return left.start_col > right.start_col
    end
    return left.row > right.row
  end)

  for _, edit in ipairs(edits) do
    vim.api.nvim_buf_set_text(
      buffer,
      edit.row - 1,
      edit.start_col,
      edit.row - 1,
      edit.end_col,
      edit.replacement
    )
  end

  local restored = restore_entries_from_marks(buffer, entries, namespace, marks)
  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)

  return restored, has_nonblank
end

local function entry_is_block_commented(buffer, entry, prefix, suffix)
  local start_row, start_col, end_row, end_col = state_module.entry_text_ranges(entry)
  if start_col < #prefix then
    return false
  end

  local start_text = table.concat(
    vim.api.nvim_buf_get_text(buffer, start_row, start_col - #prefix, start_row, start_col, {}),
    "\n"
  )
  if start_text ~= prefix then
    return false
  end

  local end_line = vim.api.nvim_buf_get_lines(buffer, end_row, end_row + 1, false)[1] or ""
  if end_col + #suffix > #end_line then
    return false
  end

  local end_text = table.concat(
    vim.api.nvim_buf_get_text(buffer, end_row, end_col, end_row, end_col + #suffix, {}),
    "\n"
  )
  return end_text == suffix
end

local function toggle_block_comments_for_entries(entries)
  if #entries == 0 then
    return false
  end

  local block_prefix, block_suffix = parse_block_comment_tokens(vim.bo.comments)
  if not block_prefix then
    local line_prefix = parse_commentstring(vim.bo.commentstring)
    if line_prefix then
      return toggle_comments_for_entries(entries)
    end

    vim.notify("block comment tokens are not available in current buffer", vim.log.levels.WARN)
    return false
  end

  local buffer = current_buffer()
  local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-toggle-block-comments")
  local marks = create_directional_entry_marks(buffer, entries, namespace)
  local all_commented = true
  local edits = {}

  for _, entry in ipairs(entries) do
    if not entry_is_block_commented(buffer, entry, block_prefix, block_suffix) then
      all_commented = false
      break
    end
  end

  for _, entry in ipairs(entries) do
    local start_row, start_col, end_row, end_col = state_module.entry_text_ranges(entry)
    if all_commented then
      edits[#edits + 1] = {
        row = end_row,
        start_col = end_col,
        end_col = end_col + #block_suffix,
        replacement = {},
      }
      edits[#edits + 1] = {
        row = start_row,
        start_col = start_col - #block_prefix,
        end_col = start_col,
        replacement = {},
      }
    else
      edits[#edits + 1] = {
        row = end_row,
        start_col = end_col,
        end_col = end_col,
        replacement = { block_suffix },
      }
      edits[#edits + 1] = {
        row = start_row,
        start_col = start_col,
        end_col = start_col,
        replacement = { block_prefix },
      }
    end
  end

  table.sort(edits, function(left, right)
    if left.row == right.row then
      return left.start_col > right.start_col
    end
    return left.row > right.row
  end)

  for _, edit in ipairs(edits) do
    vim.api.nvim_buf_set_text(
      buffer,
      edit.row,
      edit.start_col,
      edit.row,
      edit.end_col,
      edit.replacement
    )
  end

  local restored = restore_entries_from_marks(buffer, entries, namespace, marks)
  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)

  return restored, true
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

local function entry_starts_before(left, right)
  if left.start_pos[1] == right.start_pos[1] then
    if left.start_pos[2] == right.start_pos[2] then
      if left.end_pos[1] == right.end_pos[1] then
        return left.end_pos[2] < right.end_pos[2]
      end

      return left.end_pos[1] < right.end_pos[1]
    end

    return left.start_pos[2] < right.start_pos[2]
  end

  return left.start_pos[1] < right.start_pos[1]
end

local function visual_column_at_pos(pos)
  local line = line_text(pos[1])
  return vim.fn.strdisplaywidth(position.prefix_by_char_count(line, math.max(pos[2] - 1, 0)))
end

local function sorted_selection_items(entries, preferred_columns)
  local items = {}
  for index, entry in ipairs(entries) do
    items[index] = {
      entry = vim.deepcopy(entry),
      preferred_col = preferred_columns and preferred_columns[index] or entry.cursor_pos[2],
      is_primary = index == 1,
    }
  end

  table.sort(items, function(left, right)
    return entry_starts_before(left.entry, right.entry)
  end)

  return items
end

local function sorted_primary_index(items)
  for index, item in ipairs(items) do
    if item.is_primary then
      return index
    end
  end

  return 1
end

local function entries_from_sorted_items(items, primary_index)
  local entries = {}
  local preferred_columns = {}

  if #items == 0 then
    return entries, preferred_columns
  end

  local primary_item = items[primary_index]
  entries[1] = vim.deepcopy(primary_item.entry)
  preferred_columns[1] = primary_item.preferred_col

  local write_index = 2
  for index, item in ipairs(items) do
    if index ~= primary_index then
      entries[write_index] = vim.deepcopy(item.entry)
      preferred_columns[write_index] = item.preferred_col
      write_index = write_index + 1
    end
  end

  return entries, preferred_columns
end

local function rotate_primary_index(index, len, direction, count)
  if len == 0 then
    return 1
  end

  local amount = count % len
  if direction == "forward" then
    return ((index - 1 + amount) % len) + 1
  end

  return ((index - 1 - amount) % len) + 1
end

local function rotate_values(values, direction, count)
  local rotated = vim.deepcopy(values)
  local len = #rotated
  if len == 0 then
    return rotated
  end

  local amount = math.min(count, len)
  if amount == 0 or amount == len then
    return rotated
  end

  if direction == "forward" then
    for _ = 1, amount do
      table.insert(rotated, 1, table.remove(rotated))
    end
  else
    for _ = 1, amount do
      table.insert(rotated, table.remove(rotated, 1))
    end
  end

  return rotated
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
    local count = vim.v.count1
    local char = getcharstr()
    if not char then
      return
    end

    remember_repeatable_motion(function()
      motion.find_char(kind, char, count)
    end)
    motion.find_char(kind, char, count)
  end
end

function M.flash_jump()
  local snapshot = capture_selection_state_snapshot()
  if not snapshot.primary_entry then
    return
  end

  collapse_to_primary_for_flash(snapshot)
  local target = flash.pick_visible_word_target(snapshot.primary_entry.cursor_pos, {
    multi_window = not snapshot.extend_mode,
  })
  if not target then
    restore_selection_state_snapshot(snapshot)
    return
  end

  if snapshot.extend_mode then
    if target.buffer ~= current_buffer() then
      vim.notify("flash jump across buffers is not supported in select mode", vim.log.levels.WARN)
      restore_selection_state_snapshot(snapshot)
      return
    end

    if target.win ~= vim.api.nvim_get_current_win() then
      vim.api.nvim_set_current_win(target.win)
    end
    state.enter_extend_mode()
    set_preview_entries({ state_module.selection_entry(snapshot.primary_entry.anchor_pos, target.pos) }, { sync_history = false })
    return
  end

  if target.win ~= vim.api.nvim_get_current_win() then
    vim.api.nvim_set_current_win(target.win)
  end
  state.clear_preview({ keep_insert_mode = true })
  state.exit_extend_mode()
  state_module.move_cursor_to_pos(target.pos)
end

function M.flash_treesitter()
  local snapshot = capture_selection_state_snapshot()
  if not snapshot.primary_entry then
    return
  end

  collapse_to_primary_for_flash(snapshot)
  local target = flash.pick_treesitter_target(snapshot.primary_entry.cursor_pos, snapshot.primary_entry)
  if not target then
    restore_selection_state_snapshot(snapshot)
    return
  end

  if target.win ~= vim.api.nvim_get_current_win() then
    vim.api.nvim_set_current_win(target.win)
  end

  state.set_preview_entries(current_buffer(), {
    state_module.selection_entry(target.start_pos, target.end_pos),
  }, { sync_history = false })
  if snapshot.extend_mode then
    state.enter_extend_mode()
  else
    state.exit_extend_mode()
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

function M.repeat_last_motion()
  if not last_repeatable_motion then
    return
  end

  replaying_last_motion = true
  local ok, err = xpcall(function()
    for _ = 1, vim.v.count1 do
      last_repeatable_motion()
    end
  end, debug.traceback)
  replaying_last_motion = false
  if not ok then
    error(err)
  end
end

function M.record_macro()
  if macro_recording_target then
    vim.cmd.normal({ args = { "q" }, bang = true })
    local target = macro_recording_target
    local native_register = macro_native_register(target)
    local macro = vim.fn.getreg(native_register)

    -- Native recording sees the typed stop key before our mapping takes over.
    -- Drop the trailing `Q` so the stored macro matches Helix behavior.
    if macro:sub(-1) == "Q" then
      macro = macro:sub(1, -2)
    end

    restore_vim_register(native_register, macro_recording_saved)

    macro_recording_target = nil
    macro_recording_saved = nil
    update_macro_recording_indicator(nil)

    local ok, err = registers.write(target, { macro })
    if not ok then
      if err then
        vim.notify(err, vim.log.levels.ERROR)
      end
      return
    end

    vim.api.nvim_echo({ { string.format("Recorded to register [%s]", target), "ModeMsg" } }, true, {})
    return
  end

  local target = registers.take_selected() or "@"
  local native_register = macro_native_register(target)
  macro_recording_target = target
  macro_recording_saved = save_vim_register(native_register)
  update_macro_recording_indicator(target)
  vim.cmd.normal({ args = { "q" .. native_register }, bang = true })
end

function M.replay_macro()
  local target = registers.take_selected() or "@"
  if macro_replaying[target] then
    vim.notify(string.format("Cannot replay from register [%s] because already replaying from same register", target), vim.log.levels.WARN)
    return
  end

  local values = registers.read(target)
  if #values ~= 1 then
    vim.notify(string.format("Register [%s] empty", target), vim.log.levels.WARN)
    return
  end

  local saved = save_vim_register(macro_transport_register)
  vim.fn.setreg(macro_transport_register, values[1], "v")
  macro_replaying[target] = true

  local ok, err = xpcall(function()
    for _ = 1, vim.v.count1 do
      vim.cmd.normal({ args = { "@" .. macro_transport_register }, bang = true })
    end
  end, debug.traceback)

  macro_replaying[target] = nil
  restore_vim_register(macro_transport_register, saved)

  if not ok then
    error(err)
  end
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

function M.transpose_splits()
  window.transpose_splits()
end

function M.swap_with_window(direction)
  window.swap_with(direction)
end

function M.new_scratch_split(direction)
  window.new_scratch_split(direction)
end

function M.toggle_focus_window()
  window.toggle_focus()
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

local function diagnostic_pos_from_byte(row1, byte_col0)
  local line = line_text(row1)
  return { row1, position.char_col_from_byte_col0(line, byte_col0) }
end

local function sorted_buffer_diagnostics()
  local diagnostics = vim.diagnostic.get(0)
  table.sort(diagnostics, function(left, right)
    if left.lnum == right.lnum then
      return left.col < right.col
    end
    return left.lnum < right.lnum
  end)
  return diagnostics
end

local function diagnostic_entry(diag, direction)
  local buffer = current_buffer()
  local start_pos = diagnostic_pos_from_byte(diag.lnum + 1, diag.col)
  local end_pos = start_pos

  if diag.end_lnum ~= nil and diag.end_col ~= nil then
    local end_boundary = diagnostic_pos_from_byte(diag.end_lnum + 1, diag.end_col)
    end_pos = (start_pos[1] == end_boundary[1] and start_pos[2] == end_boundary[2])
      and start_pos or position.prev_pos(buffer, end_boundary)
  end

  if direction == "backward" then
    return state_module.selection_entry(end_pos, start_pos)
  end
  return state_module.selection_entry(start_pos, end_pos)
end

local function pos_before(left, right)
  return left[1] < right[1] or (left[1] == right[1] and left[2] < right[2])
end

local function find_relative_diagnostic(diagnostics, cursor_pos, direction, count)
  local current_pos = cursor_pos
  local current = nil

  for _ = 1, count do
    local best = nil
    local best_pos = nil
    for _, diag in ipairs(diagnostics) do
      local diag_pos = diagnostic_pos_from_byte(diag.lnum + 1, diag.col)
      if direction == "forward" then
        if pos_before(current_pos, diag_pos)
          and (not best_pos or pos_before(diag_pos, best_pos)) then
          best = diag
          best_pos = diag_pos
        end
      else
        if pos_before(diag_pos, current_pos)
          and (not best_pos or pos_before(best_pos, diag_pos)) then
          best = diag
          best_pos = diag_pos
        end
      end
    end

    if not best then
      break
    end

    current = best
    current_pos = diagnostic_entry(best, direction).cursor_pos
  end

  return current
end

function M.goto_diagnostic(direction)
  local count = vim.v.count1
  remember_repeatable_motion(function()
    M.goto_diagnostic(direction)
  end)

  local diagnostics = sorted_buffer_diagnostics()
  if #diagnostics == 0 then
    return
  end

  local entries = {}
  local moved_any = false
  local source_entries = preview_or_cursor_entries()
  local in_extend_mode = state.extend_mode_active()

  for index, entry in ipairs(source_entries) do
    local diag = find_relative_diagnostic(diagnostics, entry.cursor_pos, direction, count)
    if not diag then
      entries[#entries + 1] = entry
    else
      moved_any = true
      local target_entry = diagnostic_entry(diag, direction)
      if in_extend_mode then
        local anchor = (state.preview_active() and state.preview.entries[index] and state.preview.entries[index].anchor_pos) or entry.anchor_pos
        entries[#entries + 1] = state_module.selection_entry(anchor, target_entry.cursor_pos)
      else
        entries[#entries + 1] = target_entry
      end
    end
  end

  if not moved_any then
    return
  end

  set_preview_entries(entries)
  if not in_extend_mode then
    state.exit_extend_mode()
  end
  vim.diagnostic.open_float(0, { scope = "cursor", focusable = false })
end

function M.goto_edge_diagnostic(edge)
  remember_repeatable_motion(function()
    M.goto_edge_diagnostic(edge)
  end)
  local diagnostics = vim.diagnostic.get(0)
  if #diagnostics == 0 then
    vim.notify("No diagnostics in current buffer", vim.log.levels.INFO)
    return
  end

  table.sort(diagnostics, function(left, right)
    if left.lnum == right.lnum then
      return left.col < right.col
    end
    return left.lnum < right.lnum
  end)

  local diagnostic = edge == "last" and diagnostics[#diagnostics] or diagnostics[1]
  vim.api.nvim_win_set_cursor(0, { diagnostic.lnum + 1, diagnostic.col })
  vim.diagnostic.open_float(0, { scope = "cursor", focusable = false })
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
  remember_repeatable_motion(function()
    M.goto_change(kind)
  end)
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
  local count = vim.v.count1
  remember_repeatable_motion(function()
    match.goto_textobject(object_name, direction, count)
  end)
  match.goto_textobject(object_name, direction, count)
end

function M.goto_treesitter_sibling(direction)
  local count = vim.v.count1
  remember_repeatable_motion(function()
    match.goto_treesitter_sibling(direction, count)
  end)
  match.goto_treesitter_sibling(direction, count)
end

function M.goto_treesitter_sibling_edge(edge)
  remember_repeatable_motion(function()
    match.goto_treesitter_sibling_edge(edge)
  end)
  match.goto_treesitter_sibling_edge(edge)
end

function M.goto_treesitter_child(edge)
  local count = vim.v.count1
  remember_repeatable_motion(function()
    match.goto_treesitter_child(edge, count)
  end)
  match.goto_treesitter_child(edge, count)
end

local function line_is_blank_text(row)
  return line_text(row):match("^%s*$") ~= nil
end

function M.goto_paragraph(direction)
  remember_repeatable_motion(function()
    M.goto_paragraph(direction)
  end)
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
            if target == last_row and not line_is_blank_text(target) and not line_is_blank_text(target - 1) then
              target_cursor_pos = { target, line_cursor_max_column(target) }
            else
              target_cursor_pos = position.prev_pos(buffer, { target, 1 })
            end
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

function M.add_newline_relative(direction, count_override)
  local count = count_override or vim.v.count1
  remember_repeatable_motion(function()
    M.add_newline_relative(direction, count)
  end)
  local entries = preview_or_cursor_entries()
  local buffer = current_buffer()
  local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-add-newline")
  local marks = {}

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
  local allowed_token_punct = {
    ["@"] = true,
    ["."] = true,
    ["_"] = true,
    ["-"] = true,
    ["+"] = true,
    ["#"] = true,
    ["$"] = true,
    ["%"] = true,
    ["?"] = true,
    ["!"] = true,
    [","] = true,
    [";"] = true,
    ["~"] = true,
    ["&"] = true,
    ["/"] = true,
    ["\\"] = true,
    [":"] = true,
    ["{"] = true,
    ["}"] = true,
  }
  local path_component_pattern = "[%w@._%+%-$#%%?!,;~&{}]+"

  local function is_absolute_path(path)
    return path:sub(1, 1) == "/" or path:match("^%a:[/\\]") ~= nil
  end

  local function entry_is_single_cell(entry)
    return entry.start_pos[1] == entry.end_pos[1] and entry.start_pos[2] == entry.end_pos[2]
  end

  local function looks_like_path_or_url(text)
    if text == "" then
      return false
    end

    if text:match("^%w[%w+.-]*://") then
      return true
    end

    if text == "/" or text == "\\" then
      return true
    end

    if text:match("^%a:[/\\]") then
      return true
    end

    if text == "~"
      or text == "."
      or text == ".."
      or text:match("^%./") ~= nil
      or text:match("^%.%./") ~= nil
      or text:match("^~[/\\]") ~= nil
      or text:match("^%$[%w_]+$") ~= nil
      or text:match("^%$[%w_]+[/\\]") ~= nil
      or text:match("^%${[^}]+}$") ~= nil
      or text:match("^%${[^}]+}[/\\]") ~= nil
    then
      return true
    end

    if text:sub(1, 1) == "/" then
      return text:match("^/" .. path_component_pattern .. "([/\\]" .. path_component_pattern .. ")*[/\\]?$") ~= nil
    end

    if text:find("/", 1, true) ~= nil or text:find("\\", 1, true) ~= nil then
      return text:match("^" .. path_component_pattern .. "([/\\]" .. path_component_pattern .. ")*[/\\]?$") ~= nil
    end

    return text:match("^[%w@._%+%-$#%%?!,;~&]+$") ~= nil
  end

  local function path_token_char(char)
    return char:match("[%w]") ~= nil or allowed_token_punct[char] == true
  end

  local function best_span_target(span_text, cursor_col)
    local best_text = nil
    local best_length = -1
    local best_start = nil
    local span_len = position.char_count(span_text)

    for start_col = 1, span_len do
      if start_col <= cursor_col + 1 then
        for end_col = start_col, span_len do
          if cursor_col <= end_col + 1 then
            local text = position.slice_by_char_range(span_text, start_col, end_col)
            if looks_like_path_or_url(text) then
              local length = end_col - start_col + 1
              if length > best_length or (length == best_length and (not best_start or start_col < best_start)) then
                best_text = text
                best_length = length
                best_start = start_col
              end
            end
          end
        end
      end
    end

    return best_text
  end

  local function detect_target_near_cursor(entry)
    local cursor = entry.cursor_pos
    local line = line_text(cursor[1])
    local cursor_col = cursor[2]
    local spans = {}
    local span_start = nil
    local line_len = position.char_count(line)

    for col = 1, line_len do
      local char = position.char_at(line, col)
      if not path_token_char(char) then
        if span_start then
          spans[#spans + 1] = { start_col = span_start, end_col = col - 1 }
          span_start = nil
        end
      elseif not span_start then
        span_start = col
      end
    end

    if span_start then
      spans[#spans + 1] = { start_col = span_start, end_col = line_len }
    end

    for _, span in ipairs(spans) do
      if span.start_col <= cursor_col + 1 and cursor_col <= span.end_col + 1 then
        local span_text = position.slice_by_char_range(line, span.start_col, span.end_col)
        local target = best_span_target(span_text, cursor_col - span.start_col + 1)
        if target then
          return target
        end
      end
    end

    return nil
  end

  if #entries == 1 and entry_is_single_cell(entries[1]) then
    targets[1] = detect_target_near_cursor(entries[1]) or state_module.get_entry_text(entries[1])
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
      local path = vim.fs.normalize(is_absolute_path(expanded) and expanded or vim.fs.joinpath(base_dir, expanded))
      if vim.fn.isdirectory(path) == 1 then
        pickers.find_files_in_directory(path)
      else
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

  local insert_entries, selection_config = insertion_entries_and_selection(entries, "start")
  local snapshot_entries, snapshot_config = insert_preview.build_snapshot(insert_entries, selection_config)
  local transaction = history.transaction(snapshot_entries, snapshot_config)

  insert.start(insert_entries, {
    selection = selection_config,
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

  local linewise = register_values_are_linewise(repeated)
  local points = {}
  local target_rows = {}
  for index, entry in ipairs(entries) do
    if linewise then
      target_rows[index] = entry.end_pos[1] + 1
    else
      points[index] = after_entry_point(entry)
    end
  end

  local transaction = history.transaction(entries, current_preview_history_config())
  local updated
  if linewise and state.preview_active() and state.extend_mode_active() then
    updated = insert_linewise_rows_preserving_selections(entries, target_rows, repeated)
  elseif linewise then
    updated = insert_linewise_rows_with_text(target_rows, repeated)
  elseif state.preview_active() and state.extend_mode_active() then
    updated = insert_around_entries_preserving_selections(entries, points, repeated)
  else
    updated = insert_points_with_text(points, repeated)
  end

  if #updated > 0 then
    if state.preview_active() and state.extend_mode_active() then
      set_preview_entries(updated, { sync_history = false })
      state.exit_extend_mode()
    else
      sync_cursors_to_entries(updated, { sync_history = false })
    end
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

  local linewise = register_values_are_linewise(repeated)
  local points = {}
  local target_rows = {}
  for index, entry in ipairs(entries) do
    if linewise then
      target_rows[index] = entry.start_pos[1]
    else
      points[index] = entry.start_pos
    end
  end

  local transaction = history.transaction(entries, current_preview_history_config())
  local updated
  if linewise and state.preview_active() and state.extend_mode_active() then
    updated = insert_linewise_rows_preserving_selections(entries, target_rows, repeated)
  elseif linewise then
    updated = insert_linewise_rows_with_text(target_rows, repeated)
  elseif state.preview_active() and state.extend_mode_active() then
    updated = insert_around_entries_preserving_selections(entries, points, repeated)
  else
    updated = insert_points_with_text(points, repeated)
  end

  if #updated > 0 then
    if state.preview_active() and state.extend_mode_active() then
      set_preview_entries(updated, { sync_history = false })
      state.exit_extend_mode()
    else
      sync_cursors_to_entries(updated, { sync_history = false })
    end
    transaction.commit_now()
  end
end

function M.yank_selection(register_name)
  register_name = selected_or_explicit_register(register_name)
  if state.preview_active() then
    local entries = current_preview_entries()
    if store_yanked_entries(entries, register_name) then
      echo_yank_status(#entries, register_name)
      if state.extend_mode_active() then
        state.exit_extend_mode()
      end
    end
    return
  end

  local entries = preview_or_cursor_entries()
  if store_yanked_entries(entries, register_name) then
    echo_yank_status(#entries, register_name)
    if state.extend_mode_active() then
      state.exit_extend_mode()
    end
  end
end

function M.yank_primary_selection(register_name)
  register_name = selected_or_explicit_register(register_name)
  local entry = state.primary_entry()
  if not entry then
    return
  end

  if store_yanked_entries({ vim.deepcopy(entry) }, register_name) then
    echo_yank_status(1, register_name)
  end
end

function M.current_selection_entries()
  return state.current_entries()
end

function M.primary_selection_entry()
  return state.primary_entry()
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
      if entry.anchor_pos[1] > entry.cursor_pos[1]
        or (entry.anchor_pos[1] == entry.cursor_pos[1] and entry.anchor_pos[2] > entry.cursor_pos[2]) then
        table.insert(entries, state_module.selection_entry(trimmed_end, trimmed_start))
      else
        table.insert(entries, state_module.selection_entry(trimmed_start, trimmed_end))
      end
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

  local compiled = compile_selection_regex(pattern)

  local kept = {}
  for _, entry in ipairs(state.preview.entries) do
    local matches = preview_entry_matches(entry, compiled)
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
  local register_name = resolve_search_register('/')
  pattern = pattern or prompt_selection_regex("select", register_name)
  if not pattern then
    return
  end

  if not set_search_register(register_name, pattern) then
    return
  end

  local compiled = compile_selection_regex(pattern)

  local matches = {}
  for _, entry in ipairs(preview_or_cursor_entries()) do
    vim.list_extend(matches, entry_regex_matches(entry, compiled))
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
    state_module.move_cursor_to_pos({ pos[1], position.char_count(line) + 1 })
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
    clear_selected_register_indicator()
    return
  end

  registers.select(register_name)
  update_selected_register_indicator(register_name)
  arm_selected_register_clear()
end

function M.clear_selected_register()
  vim.on_key(nil, selected_register_clear_ns)
  clear_selected_register_indicator()
end

function M.register_selectable_names()
  return registers.selectable_names()
end

function M.which_key_registers()
  return registers.which_key_entries(function(name)
    M.select_register(name)
  end)
end

function M.which_key_register_items()
  local items = {}
  for index, entry in ipairs(M.which_key_registers()) do
    items[#items + 1] = {
      key = entry[1],
      value = entry.desc or "",
      desc = "",
      order = index,
      action = entry[2],
    }
  end
  return items
end

function M.read_register(register_name)
  return registers.read(register_name)
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
  local char = getcharstr()
  if not char then
    return
  end

  remember_repeatable_motion(function()
    match.select_textobject_char(char, true)
  end)
  match.select_textobject_char(char, true)
end

function M.select_inside_pair()
  local char = getcharstr()
  if not char then
    return
  end

  remember_repeatable_motion(function()
    match.select_textobject_char(char, false)
  end)
  match.select_textobject_char(char, false)
end

function M.goto_match()
  remember_repeatable_motion(function()
    M.goto_match()
  end)
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

function M.toggle_comments()
  local had_preview = state.preview_active()
  local entries = had_preview and current_preview_entries() or preview_or_cursor_entries()
  local transaction = history.transaction(entries, current_preview_history_config())
  local updated, changed = toggle_comments_for_entries(entries)
  if not updated then
    return
  end

  if had_preview then
    set_preview_entries(updated, { sync_history = false })
  else
    sync_cursors_to_entries(updated, { sync_history = false })
  end

  state.exit_extend_mode()
  if changed then
    transaction.commit_now()
  end
end

function M.toggle_line_comments()
  local had_preview = state.preview_active()
  local entries = had_preview and current_preview_entries() or preview_or_cursor_entries()
  local transaction = history.transaction(entries, current_preview_history_config())
  local updated, changed = toggle_comments_for_entries(entries)
  if not updated then
    return
  end

  if had_preview then
    set_preview_entries(updated, { sync_history = false })
  else
    sync_cursors_to_entries(updated, { sync_history = false })
  end

  state.exit_extend_mode()
  if changed then
    transaction.commit_now()
  end
end

function M.toggle_block_comments()
  local had_preview = state.preview_active()
  local entries = had_preview and current_preview_entries() or preview_or_cursor_entries()
  local transaction = history.transaction(entries, current_preview_history_config())
  local updated, changed = toggle_block_comments_for_entries(entries)
  if not updated then
    return
  end

  if had_preview then
    set_preview_entries(updated, { sync_history = false })
  else
    sync_cursors_to_entries(updated, { sync_history = false })
  end

  state.exit_extend_mode()
  if changed then
    transaction.commit_now()
  end
end

local function increment_selections(direction)
  local sign = direction == "increase" and 1 or -1
  local register_name = selected_or_explicit_register()
  local amount = sign * vim.v.count1
  local increase_by = register_name == "#" and sign or 0
  local had_preview = state.preview_active()
  local entries = had_preview and current_preview_entries() or preview_or_cursor_entries()
  local replacements = {}
  local changed = false

  for index, entry in ipairs(entries) do
    local text = state_module.get_entry_text(entry)
    local replacement = increment_integer_text(text, amount)
    replacements[index] = replacement or text
    if replacement and replacement ~= text then
      changed = true
    end
    amount = amount + increase_by
  end

  if not changed then
    return
  end

  local transaction = history.transaction(entries, current_preview_history_config())
  local updated = replace_preview_entries_with_text(entries, replacements)
  if had_preview then
    set_preview_entries(updated, { sync_history = false })
  else
    sync_cursors_to_entries(updated, { sync_history = false })
  end
  state.exit_extend_mode()
  transaction.commit_now()
end

function M.increment()
  increment_selections("increase")
end

function M.decrement()
  increment_selections("decrease")
end

function M.format_selections()
  local had_preview = state.preview_active()
  local entries = had_preview and current_preview_entries() or preview_or_cursor_entries()
  if #entries ~= 1 then
    vim.notify("format_selections only supports a single selection for now", vim.log.levels.WARN)
    return
  end

  if not next(vim.lsp.get_clients({ bufnr = current_buffer(), method = "textDocument/rangeFormatting" })) then
    vim.notify("No configured language server supports range formatting", vim.log.levels.WARN)
    return
  end

  local buffer = current_buffer()
  local entry = entries[1]
  local start_row, start_col, end_row, end_col = state_module.entry_text_ranges(entry)
  local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-format-selection")
  local marks = create_entry_marks(buffer, entries, namespace)
  local history_config = current_preview_history_config()
  local transaction = history.transaction(entries, history_config)

  vim.lsp.buf.format({
    async = false,
    bufnr = buffer,
    timeout_ms = 1000,
    range = {
      start = { start_row + 1, start_col },
      ["end"] = { end_row + 1, end_col },
    },
  })

  local updated = restore_entries_from_marks(buffer, entries, namespace, marks)
  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)

  if had_preview then
    set_preview_entries(updated, { sync_history = false })
  else
    state_module.move_cursor_to_pos(updated[1].cursor_pos)
  end

  transaction.commit_now()
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

function M.copy_selection_on_adjacent_line(delta, count_override)
  local count = count_override or vim.v.count1
  local function clone_once()
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
      return false
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
    else
      sync_cursors_to_entries(combined_entries, { preferred_columns = combined_preferred_columns })
    end

    return true
  end

  for _ = 1, count do
    if not clone_once() then
      break
    end
  end
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

function M.align_selections()
  local had_preview = state.preview_active()
  local entries = had_preview and current_preview_entries() or preview_or_cursor_entries()
  if #entries == 0 then
    state.exit_extend_mode()
    return
  end

  for _, entry in ipairs(entries) do
    if entry.start_pos[1] ~= entry.end_pos[1] then
      vim.notify("align cannot work with multi line selections", vim.log.levels.ERROR)
      return
    end
  end

  if not had_preview and #entries == 1 then
    state.exit_extend_mode()
    return
  end

  local buffer = current_buffer()
  local transaction = history.transaction(entries, current_preview_history_config())
  local selection_namespace = vim.api.nvim_create_namespace("axelcool1234-helix-align-selection")
  local insert_namespace = vim.api.nvim_create_namespace("axelcool1234-helix-align-insert")
  local selection_marks = create_entry_marks(buffer, entries, selection_namespace)
  local sorted_entries = {}
  local row_groups = {}
  local row_offsets = {}
  local inserted = false
  local max_columns = 0

  for index, entry in ipairs(entries) do
    sorted_entries[index] = {
      index = index,
      entry = entry,
    }
  end

  table.sort(sorted_entries, function(left, right)
    return entry_starts_before(left.entry, right.entry)
  end)

  for _, item in ipairs(sorted_entries) do
    local row = item.entry.start_pos[1]
    local group = row_groups[#row_groups]
    if not group or group.row ~= row then
      group = { row = row, items = {} }
      row_groups[#row_groups + 1] = group
      row_offsets[#row_groups] = 0
    end

    local start_row, start_col = position.before_boundary(buffer, item.entry.start_pos)
    group.items[#group.items + 1] = {
      head_col = visual_column_at_pos(item.entry.cursor_pos),
      mark_id = vim.api.nvim_buf_set_extmark(buffer, insert_namespace, start_row, start_col, {
        right_gravity = false,
      }),
    }
    max_columns = math.max(max_columns, #group.items)
  end

  for column_index = 1, max_columns do
    local max_col = nil

    for row_index, group in ipairs(row_groups) do
      local item = group.items[column_index]
      if item then
        local effective_col = item.head_col + row_offsets[row_index]
        max_col = max_col and math.max(max_col, effective_col) or effective_col
      end
    end

    if max_col then
      for row_index, group in ipairs(row_groups) do
        local item = group.items[column_index]
        if item then
          local effective_col = item.head_col + row_offsets[row_index]
          local insert_count = max_col - effective_col
          if insert_count > 0 then
            local insert_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, insert_namespace, item.mark_id, {})
            if #insert_pos > 0 then
              vim.api.nvim_buf_set_text(
                buffer,
                insert_pos[1],
                insert_pos[2],
                insert_pos[1],
                insert_pos[2],
                { string.rep(" ", insert_count) }
              )
              row_offsets[row_index] = row_offsets[row_index] + insert_count
              inserted = true
            end
          end
        end
      end
    end
  end

  vim.api.nvim_buf_clear_namespace(buffer, insert_namespace, 0, -1)

  if inserted then
    local updated = restore_entries_from_marks(buffer, entries, selection_namespace, selection_marks)
    if had_preview then
      set_preview_entries(updated, { sync_history = false })
    else
      sync_cursors_to_entries(updated, { sync_history = false })
    end
    transaction.commit_now()
  end

  vim.api.nvim_buf_clear_namespace(buffer, selection_namespace, 0, -1)
  state.exit_extend_mode()
end

function M.rotate_selections(direction)
  local entries = state.preview_active() and current_preview_entries() or preview_or_cursor_entries()
  if #entries <= 1 then
    return
  end

  local preferred_columns = state.current_preferred_columns()
  local items = sorted_selection_items(entries, preferred_columns)
  local primary_index = sorted_primary_index(items)
  local new_primary_index = rotate_primary_index(primary_index, #items, direction, vim.v.count1)
  local reordered_entries, reordered_preferred_columns = entries_from_sorted_items(items, new_primary_index)

  set_preview_entries(reordered_entries, { preferred_columns = reordered_preferred_columns })
end

function M.rotate_selection_contents(direction)
  local had_preview = state.preview_active()
  local entries = had_preview and current_preview_entries() or preview_or_cursor_entries()
  if #entries <= 1 then
    return
  end

  local preferred_columns = state.current_preferred_columns()
  local items = sorted_selection_items(entries, preferred_columns)
  local sorted_entries = {}
  local contents = {}
  for index, item in ipairs(items) do
    sorted_entries[index] = item.entry
    contents[index] = state_module.get_entry_text(item.entry)
  end

  local amount = math.min(vim.v.count1, #items)
  local rotated_contents = rotate_values(contents, direction, amount)
  local new_primary_index = rotate_primary_index(sorted_primary_index(items), #items, direction, amount)
  local transaction = history.transaction(entries, current_preview_history_config())
  local updated = replace_preview_entries_with_text(sorted_entries, rotated_contents)
  local updated_items = {}

  for index, item in ipairs(items) do
    updated_items[index] = {
      entry = updated[index],
      preferred_col = item.preferred_col,
      is_primary = index == new_primary_index,
    }
  end

  local reordered_entries, reordered_preferred_columns = entries_from_sorted_items(updated_items, new_primary_index)
  if had_preview then
    set_preview_entries(reordered_entries, { preferred_columns = reordered_preferred_columns, sync_history = false })
  else
    sync_cursors_to_entries(reordered_entries, { preferred_columns = reordered_preferred_columns, sync_history = false })
  end
  transaction.commit_now()
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
      if incremental_search.ignore_cursor_moved > 0 then
        incremental_search.ignore_cursor_moved = incremental_search.ignore_cursor_moved - 1
        return
      end

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
