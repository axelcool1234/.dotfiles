local state_module = require("axelcool1234.helix.state")
local position = require("axelcool1234.helix.position")

local M = {}

local character_types = {
  WhiteSpace = 1,
  Word = 2,
  Punctuation = 3,
  EndOfLine = 4,
  Unknown = 5,
}

local function buffer_line(buffer, row)
  return position.line_text(buffer, row)
end

local function cursor_max_column(buffer, row)
  return position.cursor_max_column(buffer, row)
end

local function run_normal_motion(keys, count)
  if keys == "G" then
    local buffer = vim.api.nvim_get_current_buf()
    local last_row = vim.api.nvim_buf_line_count(buffer)
    local target_row = count and count > 0 and math.min(count, last_row) or last_row
    vim.api.nvim_win_set_cursor(0, { target_row, 0 })
    return
  end

  vim.cmd(("normal! %d%s"):format(count or 1, keys))
end

local function pos_equal(left, right)
  return left[1] == right[1] and left[2] == right[2]
end

local function normalize_find_char(char)
  if char == "\r" then
    return "\n"
  end

  return char
end

local function char_at_pos(buffer, pos)
  if position.is_newline_pos(buffer, pos) then
    return "\n"
  end

  local line = buffer_line(buffer, pos[1])
  return line:sub(pos[2], pos[2])
end

local function step_pos(buffer, pos, forward)
  if forward then
    return position.next_pos(buffer, pos)
  end

  return position.prev_pos(buffer, pos)
end

local function find_char_target(buffer, start_pos, char, opts)
  local target_char = normalize_find_char(char)
  local pos = { start_pos[1], start_pos[2] }
  local remaining = opts.count or 1

  while remaining > 0 do
    local found = false

    while true do
      local next_pos = step_pos(buffer, pos, opts.forward)
      if pos_equal(next_pos, pos) then
        return nil
      end

      pos = next_pos
      if char_at_pos(buffer, pos) == target_char then
        if opts.till then
          local till_target = step_pos(buffer, pos, not opts.forward)
          if pos_equal(till_target, start_pos) then
            goto continue_find
          end
        end

        found = true
        break
      end

      ::continue_find::
    end

    if not found then
      return nil
    end

    remaining = remaining - 1
  end

  if opts.till then
    return step_pos(buffer, pos, not opts.forward)
  end

  return pos
end

local function character_type(char)
  if char == "\n" then
    return character_types.EndOfLine
  end
  if char:match("%s") then
    return character_types.WhiteSpace
  end
  if char:match("[%w_]") then
    return character_types.Word
  end
  if char:match("[^%s%w_]") then
    return character_types.Punctuation
  end
  return character_types.Unknown
end

local function current_char(current_pos, line_content)
  return line_content:sub(current_pos[2], current_pos[2])
end

local function next_char(current_pos, line_content)
  if current_pos[2] < #line_content then
    return line_content:sub(current_pos[2] + 1, current_pos[2] + 1)
  end
  return "\n"
end

local function prev_char(current_pos, line_content)
  if current_pos[2] > 1 then
    return line_content:sub(current_pos[2] - 1, current_pos[2] - 1)
  end
  return "\n"
end

local function word_motion_bounds(buffer, target, count, start_pos)
  local is_prev = target == "prev_word_start" or target == "prev_long_word_start"
  local line = start_pos[1]
  local line_content = buffer_line(buffer, line)
  local current_pos = { start_pos[1], start_pos[2] }
  local range_start = { current_pos[1], current_pos[2] }
  local range_end = { current_pos[1], current_pos[2] }
  local last_line = vim.api.nvim_buf_line_count(buffer)

  for _ = 1, count do
    line = current_pos[1]
    line_content = buffer_line(buffer, line)
    range_start = { current_pos[1], current_pos[2] }
    range_end = { current_pos[1], current_pos[2] }
    local moved_from_original = false

    if is_prev then
      while true do
        local current_type = character_type(current_char(current_pos, line_content))
        local prev_type = character_type(prev_char(current_pos, line_content))

        if range_start[2] ~= current_pos[2] then
          if prev_type == character_types.EndOfLine then
            break
          end

          if target == "prev_word_start" then
            if (current_type == character_types.Word and prev_type ~= character_types.Word)
              or (current_type == character_types.Punctuation and prev_type ~= character_types.Punctuation) then
              break
            end
          end

          if target == "prev_long_word_start" then
            if (current_type == character_types.Word and prev_type == character_types.WhiteSpace)
              or (current_type == character_types.Punctuation and prev_type == character_types.WhiteSpace) then
              break
            end
          end
        else
          if current_type == character_types.EndOfLine
            or prev_type == character_types.EndOfLine
            or current_type == character_types.Unknown then
            if moved_from_original and current_type ~= character_types.Unknown then
              break
            end
            if current_pos[1] == 1 then
              break
            end

            current_pos[1] = current_pos[1] - 1
            line_content = buffer_line(buffer, current_pos[1])
            current_pos[2] = #line_content
            range_start = { current_pos[1], current_pos[2] }
            range_end = { current_pos[1], current_pos[2] }
            moved_from_original = true
            goto continue_prev
          end

          if moved_from_original then
            if prev_type == character_types.EndOfLine then
              break
            end

            if (current_type == character_types.Punctuation and prev_type ~= character_types.Punctuation)
              or (current_type == character_types.Word and prev_type ~= character_types.Word) then
              break
            end
          else
            if (current_type == character_types.Punctuation and prev_type ~= character_types.Punctuation)
              or (current_type == character_types.Word and prev_type ~= character_types.Word) then
              range_start[2] = range_start[2] - 1
              moved_from_original = true
            end
          end
        end

        current_pos[2] = current_pos[2] - 1
        if current_pos[2] <= 1 then
          break
        end

        ::continue_prev::
      end
    else
      while true do
        local current_type = character_type(current_char(current_pos, line_content))
        local next_type = character_type(next_char(current_pos, line_content))

        if range_start[2] ~= current_pos[2] then
          if next_type == character_types.EndOfLine then
            break
          end

          if target == "next_word_start" then
            if (current_type == character_types.WhiteSpace and next_type ~= character_types.WhiteSpace)
              or (current_type == character_types.Punctuation and next_type == character_types.Word)
              or (current_type ~= character_types.Punctuation and next_type == character_types.Punctuation) then
              break
            end
          end

          if target == "next_long_word_start" then
            if current_type == character_types.WhiteSpace and next_type ~= character_types.WhiteSpace then
              break
            end
          end

          if target == "next_word_end" then
            if (current_type == character_types.Word and next_type ~= character_types.Word)
              or (current_type ~= character_types.Punctuation and next_type == character_types.Punctuation)
              or (current_type == character_types.Punctuation and next_type ~= character_types.Punctuation) then
              break
            end
          end

          if target == "next_long_word_end" then
            if current_type ~= character_types.WhiteSpace and next_type == character_types.WhiteSpace then
              break
            end
          end
        else
          if current_type == character_types.EndOfLine
            or next_type == character_types.EndOfLine
            or current_type == character_types.Unknown then
            if moved_from_original and current_type ~= character_types.Unknown then
              break
            end
            if current_pos[1] == last_line then
              break
            end

            current_pos[1] = current_pos[1] + 1
            current_pos[2] = 1
            range_start = { current_pos[1], current_pos[2] }
            range_end = { current_pos[1], current_pos[2] }
            line_content = buffer_line(buffer, current_pos[1])
            moved_from_original = true
            goto continue_next
          end

          if moved_from_original then
            if next_type == character_types.EndOfLine then
              break
            end

            if target == "next_word_start" then
              if (current_type ~= character_types.Punctuation and next_type == character_types.Punctuation)
                or (current_type == character_types.Punctuation and next_type == character_types.Word) then
                break
              end
            end

            if target == "next_word_end" then
              if (current_type == character_types.Word and next_type ~= character_types.Word)
                or (current_type == character_types.Punctuation and next_type ~= character_types.Punctuation) then
                break
              end
            end
          else
            if target == "next_word_start" then
              if (current_type ~= character_types.Punctuation and next_type == character_types.Punctuation)
                or (current_type == character_types.Punctuation and next_type == character_types.Word)
                or (current_type == character_types.WhiteSpace and next_type == character_types.Word) then
                range_start[2] = range_start[2] + 1
                moved_from_original = true
              end
            end

            if target == "next_long_word_start" then
              if current_type == character_types.WhiteSpace and next_type ~= character_types.WhiteSpace then
                range_start[2] = range_start[2] + 1
                moved_from_original = true
              end
            end

            if target == "next_word_end" or target == "next_long_word_end" then
              if (current_type == character_types.Word and next_type ~= character_types.Word)
                or (current_type == character_types.Punctuation and next_type ~= character_types.Punctuation) then
                range_start[2] = range_start[2] + 1
                moved_from_original = true
              end
            end
          end
        end

        current_pos[2] = current_pos[2] + 1
        if current_pos[2] > #line_content then
          break
        end

        ::continue_next::
      end
    end

    range_end = { current_pos[1], current_pos[2] }
  end

  return range_start, range_end
end

function M.new(opts)
  local state = opts.state

  local motion = {}

  local function first_nonblank_col(line)
    local col = line:find("%S")
    return col or 1
  end

  local function direct_motion_target(buffer, pos, keys)
    local row = pos[1]
    local line = buffer_line(buffer, row)

    if keys == "^" then
      return { row, first_nonblank_col(line) }
    end

    if keys == "$" then
      return { row, math.max(#line, 1) }
    end

    if keys == "G" then
      local last_row = vim.api.nvim_buf_line_count(buffer)
      local target_row = vim.v.count > 0 and math.min(vim.v.count, last_row) or last_row
      return { target_row, 1 }
    end

    return nil
  end

  local function word_motion_entry(buffer, start_pos, target, count)
    local anchor_pos, cursor_pos = word_motion_bounds(buffer, target, count, start_pos)
    return state_module.selection_entry(anchor_pos, cursor_pos)
  end

  local function apply_row_jump(target_row)
    local buffer = vim.api.nvim_get_current_buf()
    local source_entries = state.current_entries()
    local entries = {}

    for index, source_entry in ipairs(source_entries) do
      local target = { target_row, 1 }

      if state.extend_mode_active() then
        local anchor = state.preview.entries[index] and state.preview.entries[index].anchor_pos or source_entry.anchor_pos
        table.insert(entries, state_module.selection_entry(anchor, target))
      else
        table.insert(entries, state_module.selection_entry(target, target))
      end
    end

    if #source_entries > 1 or state.extend_mode_active() then
      state.set_preview_entries(buffer, entries)
      if not state.extend_mode_active() then
        state.exit_extend_mode()
      end
      return
    end

    state_module.move_cursor_to_pos(entries[1].cursor_pos)
  end

  local function scroll_view_delta(direction)
    local view = vim.fn.winsaveview()
    local amount = vim.v.count > 0 and vim.v.count or math.max(math.floor(vim.api.nvim_win_get_height(0) / 2), 1)
    local probe = vim.deepcopy(view)
    probe.topline = math.max(1, view.topline + (direction * amount))

    vim.fn.winrestview(probe)
    local adjusted = vim.fn.winsaveview()
    vim.fn.winrestview(view)

    return adjusted.topline - view.topline, view
  end

  function motion.scroll_half_page(direction)
    local buffer = vim.api.nvim_get_current_buf()
    local source_entries = state.current_entries()
    local preferred_columns = state.current_preferred_columns()
    local amount = vim.v.count > 0 and vim.v.count or math.max(math.floor(vim.api.nvim_win_get_height(0) / 2), 1)
    local delta, initial_view = scroll_view_delta(direction)
    local last_row = vim.api.nvim_buf_line_count(buffer)
    local entries = {}
    local next_preferred_columns = {}

    for index, source_entry in ipairs(source_entries) do
      local preferred_col = preferred_columns[index] or source_entry.cursor_pos[2]
      local target_row = math.max(1, math.min(source_entry.cursor_pos[1] + (direction * amount), last_row))
      local target_col = math.min(preferred_col, cursor_max_column(buffer, target_row))
      local target = { target_row, target_col }

      if state.extend_mode_active() then
        local anchor = state.preview.entries[index] and state.preview.entries[index].anchor_pos or source_entry.anchor_pos
        table.insert(entries, state_module.selection_entry(anchor, target))
      else
        table.insert(entries, state_module.selection_entry(target, target))
      end

      next_preferred_columns[index] = preferred_col
    end

    local final_view = vim.deepcopy(initial_view)
    final_view.topline = initial_view.topline + delta
    final_view.lnum = entries[1].cursor_pos[1]
    final_view.col = math.max(entries[1].cursor_pos[2] - 1, 0)
    if final_view.curswant ~= nil then
      final_view.curswant = math.max(next_preferred_columns[1] - 1, 0)
    end

    if #source_entries > 1 or state.extend_mode_active() then
      state.set_preview_entries(buffer, entries, { preferred_columns = next_preferred_columns })
      vim.fn.winrestview(final_view)
      if not state.extend_mode_active() then
        state.exit_extend_mode()
      end
      return
    end

    if state.preview_active() then
      state.clear_preview()
    end

    state_module.move_cursor_to_pos(entries[1].cursor_pos)
    vim.fn.winrestview(final_view)
  end

  function motion.goto_last_line()
    local last_row = vim.api.nvim_buf_line_count(vim.api.nvim_get_current_buf())
    apply_row_jump(last_row)
  end

  function motion.goto_line()
    local buffer = vim.api.nvim_get_current_buf()
    local last_row = vim.api.nvim_buf_line_count(buffer)
    local target_row = vim.v.count > 0 and math.min(vim.v.count, last_row) or last_row
    apply_row_jump(target_row)
  end

  function motion.apply_word(target)
    local buffer = vim.api.nvim_get_current_buf()
    local count = vim.v.count1
    local entries = {}
    local source_entries = state.current_entries()

    local function append_entry(source_entry, index)
      local entry = word_motion_entry(buffer, source_entry.cursor_pos, target, count)
      if state.extend_mode_active() then
        local anchor = state.preview.entries[index] and state.preview.entries[index].anchor_pos or source_entry.cursor_pos
        table.insert(entries, state_module.selection_entry(anchor, entry.cursor_pos))
      else
        table.insert(entries, entry)
      end
    end

    for index, entry in ipairs(source_entries) do
      append_entry(entry, index)
    end

    state.set_preview_entries(buffer, entries)
    if not state.extend_mode_active() then
      state.exit_extend_mode()
    end
  end

  function motion.find_char(kind, char)
    local buffer = vim.api.nvim_get_current_buf()
    local count = vim.v.count1
    local source_entries = state.current_entries()
    local entries = {}
    local matched_any = false
    local opts = {
      count = count,
      forward = kind == "f" or kind == "t",
      till = kind == "t" or kind == "T",
    }

    for index, source_entry in ipairs(source_entries) do
      local target = find_char_target(buffer, source_entry.cursor_pos, char, opts)
      if target then
        matched_any = true
      else
        target = source_entry.cursor_pos
      end

      if state.extend_mode_active() then
        local anchor = state.preview.entries[index] and state.preview.entries[index].anchor_pos or source_entry.anchor_pos
        table.insert(entries, state_module.selection_entry(anchor, target))
      else
        table.insert(entries, state_module.selection_entry(source_entry.cursor_pos, target))
      end
    end

    if not matched_any then
      return
    end

    state.set_preview_entries(buffer, entries)
    if not state.extend_mode_active() then
      state.exit_extend_mode()
    end
  end

  function motion.normal(keys)
    return function()
      local count = vim.v.count1
      local buffer = vim.api.nvim_get_current_buf()
      local source_entries = state.current_entries()
      local preferred_columns = state.current_preferred_columns()

      if keys == "j" or keys == "k" then
        if #source_entries == 1 and not state.preview_active() and not state.extend_mode_active() then
          run_normal_motion(keys, count)
          return
        end

        local delta = keys == "j" and 1 or -1
        local last_row = vim.api.nvim_buf_line_count(buffer)
        local entries = {}
        local next_preferred_columns = {}

        for index, source_entry in ipairs(source_entries) do
          local preferred_col = preferred_columns[index] or source_entry.cursor_pos[2]
          local target_row = math.max(1, math.min(source_entry.cursor_pos[1] + (delta * count), last_row))
          local target_col = math.min(preferred_col, cursor_max_column(buffer, target_row))
          local target = { target_row, target_col }

          if state.extend_mode_active() then
            local anchor = state.preview.entries[index] and state.preview.entries[index].anchor_pos or source_entry.anchor_pos
            table.insert(entries, state_module.selection_entry(anchor, target))
          else
            table.insert(entries, state_module.selection_entry(target, target))
          end

          next_preferred_columns[index] = preferred_col
        end

        if #source_entries > 1 or state.extend_mode_active() or state.preview_active() then
          state.set_preview_entries(buffer, entries, { preferred_columns = next_preferred_columns })
          if not state.extend_mode_active() then
            state.exit_extend_mode()
          end
          return
        end
      end

      local function collect_entries(anchor_from_preview)
        local entries = {}

        for index, source_entry in ipairs(source_entries) do
          state_module.move_cursor_to_pos(source_entry.cursor_pos)
          run_normal_motion(keys, count)
          local pos = state_module.current_pos_1indexed()
          if anchor_from_preview then
            local anchor = state.preview.entries[index] and state.preview.entries[index].anchor_pos or source_entry.anchor_pos
            table.insert(entries, state_module.selection_entry(anchor, pos))
          else
            table.insert(entries, state_module.selection_entry(pos, pos))
          end
        end

        return entries
      end

      if state.extend_mode_active() then
        local direct_entries = {}
        local used_direct_motion = false

        local function append_direct_entry(source_entry, index)
          local target = direct_motion_target(buffer, source_entry.cursor_pos, keys)
          if not target then
            return false
          end

          used_direct_motion = true
          local anchor = source_entry.anchor_pos
          if state.preview_active() and state.preview.entries[index] then
            anchor = state.preview.entries[index].anchor_pos or state.preview.entries[index].start_pos
          end
          table.insert(direct_entries, state_module.selection_entry(anchor, target))
          return true
        end

        for index, source_entry in ipairs(source_entries) do
          append_direct_entry(source_entry, index)
        end

        if used_direct_motion then
          state.set_preview_entries(buffer, direct_entries)
          return
        end

        state.set_preview_entries(buffer, collect_entries(true))
        return
      end

      if #source_entries > 1 then
        state.set_preview_entries(buffer, collect_entries(false))
        return
      end

      run_normal_motion(keys, count)
    end
  end

  return motion
end

return M
