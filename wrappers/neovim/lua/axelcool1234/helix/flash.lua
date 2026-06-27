local M = {}

local label_alphabet = "asdfjklghqwertyuiopzxcvbnmASDFJKLGHQWERTYUIOPZXCVBNM"

local function setup_highlights()
  vim.api.nvim_set_hl(0, "HelixFlashLabel", { link = "Substitute", default = true })
  vim.api.nvim_set_hl(0, "HelixFlashTarget", { link = "Search", default = true })
  vim.api.nvim_set_hl(0, "HelixFlashCurrent", { link = "IncSearch", default = true })
  vim.api.nvim_set_hl(0, "HelixFlashBackdrop", { link = "Comment", default = true })
end

local function same_pos(left, right)
  return left[1] == right[1] and left[2] == right[2]
end

local function same_range(entry, start_pos, end_pos)
  return entry
    and entry.start_pos
    and entry.end_pos
    and same_pos(entry.start_pos, start_pos)
    and same_pos(entry.end_pos, end_pos)
end

local function pos_id(pos, win)
  return string.format("%d:%d:%d", win or 0, pos[1], pos[2])
end

local function range_id(start_pos, end_pos, win)
  return string.format("%d:%d:%d:%d:%d", win or 0, start_pos[1], start_pos[2], end_pos[1], end_pos[2])
end

local function key_code(char)
  if not char then
    return nil
  end
  return vim.fn.keytrans(char)
end

local function is_printable_char(char)
  return type(char) == "string" and vim.fn.strchars(char) == 1 and key_code(char) == char
end

local function smart_case_fold(text, pattern)
  if pattern:find("%u") then
    return text
  end
  return text:lower()
end

function M.new(opts)
  local flash = {}
  local position = assert(opts.position, "position helper is required")
  local getcharstr = assert(opts.getcharstr, "getcharstr helper is required")
  local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-flash")

  setup_highlights()

  local function clear(buffers)
    if type(buffers) == "number" then
      buffers = { buffers }
    end

    for _, buffer in ipairs(buffers or vim.api.nvim_list_bufs()) do
      if buffer and vim.api.nvim_buf_is_valid(buffer) then
        vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
      end
    end
    vim.api.nvim_echo({}, false, {})
  end

  local function visible_window_info(win)
    return vim.fn.getwininfo(win)[1]
  end

  local function compile_exact_pattern(pattern)
    if pattern == "" then
      return nil
    end

    local compiled = "\\V" .. pattern:gsub("\\", "\\\\")
    if vim.o.ignorecase then
      if vim.o.smartcase and pattern:find("[A-Z]") then
        compiled = compiled .. "\\C"
      else
        compiled = compiled .. "\\c"
      end
    end
    return compiled
  end

  local function window_match_info(wins, current_win)
    local info = {}
    for index, win in ipairs(wins) do
      info[win] = {
        rank = win == current_win and 0 or index,
        is_current = win == current_win,
      }
    end
    return info
  end

  local function collect_visible_matches(wins, current_win, origin, pattern)
    local compiled = compile_exact_pattern(pattern)
    if not compiled then
      return {}
    end

    local win_info = window_match_info(wins, current_win)
    local matches = {}

    for _, win in ipairs(wins) do
      local info = visible_window_info(win)
      if info then
        local buffer = vim.api.nvim_win_get_buf(win)
        local max_row = math.min(info.botline, vim.api.nvim_buf_line_count(buffer))
        local width = math.max(vim.api.nvim_win_get_width(win), 1)

        for row = info.topline, max_row do
          local line = position.line_text(buffer, row)
          local byteidx = 0

          while true do
            local match = vim.fn.matchstrpos(line, compiled, byteidx)
            local text = match[1]
            local start_byte = match[2]
            local end_byte = match[3]
            if start_byte < 0 then
              break
            end

            local char_col = position.char_col_from_byte_col0(line, start_byte)
            local target_pos = { row, char_col }
            if win ~= current_win or not same_pos(target_pos, origin) then
              matches[#matches + 1] = {
                win = win,
                buffer = buffer,
                pos = target_pos,
                text = text,
                next_char = position.char_at(line, position.char_col_from_byte_col0(line, end_byte)),
                distance = math.abs(row - origin[1]) * width + math.abs(char_col - origin[2]),
                win_rank = win_info[win].rank,
                current_window = win_info[win].is_current,
              }
            end

            byteidx = math.max(end_byte, start_byte + 1)
          end
        end
      end
    end

    table.sort(matches, function(left, right)
      if left.win_rank ~= right.win_rank then
        return left.win_rank < right.win_rank
      end
      if left.distance == right.distance then
        if left.pos[1] == right.pos[1] then
          return left.pos[2] < right.pos[2]
        end
        return left.pos[1] < right.pos[1]
      end
      return left.distance < right.distance
    end)

    return matches
  end

  local function next_chars_for_matches(matches, pattern)
    local next_chars = {}
    for _, match in ipairs(matches) do
      local next_char = match.next_char
      if next_char then
        next_chars[smart_case_fold(next_char, pattern)] = true
      end
    end
    return next_chars
  end

  local function assign_labels(matches, pattern, used_labels)
    local labels = vim.split(label_alphabet, "")
    local disallowed = next_chars_for_matches(matches, pattern)
    local available = {}

    for _, label in ipairs(labels) do
      if not disallowed[smart_case_fold(label, pattern)] then
        available[#available + 1] = label
      end
    end

    local available_lookup = {}
    for _, label in ipairs(available) do
      available_lookup[label] = true
    end

    local labeled = {}
    for _, candidate in ipairs(matches) do
      local match = vim.deepcopy(candidate)
      local preserved = used_labels[pos_id(match.pos, match.win)]
      if preserved and available_lookup[preserved] then
        match.label = preserved
        labeled[#labeled + 1] = match
        available_lookup[preserved] = nil
        available = vim.tbl_filter(function(label)
          return label ~= preserved
        end, available)
      end
    end

    local assigned = {}
    for _, match in ipairs(labeled) do
      assigned[pos_id(match.pos, match.win)] = true
    end

    for _, candidate in ipairs(matches) do
      if #available == 0 then
        break
      end

      local id = pos_id(candidate.pos, candidate.win)
      if not assigned[id] then
        local match = vim.deepcopy(candidate)
        match.label = available[1]
        labeled[#labeled + 1] = match
        table.remove(available, 1)
      end
    end

    local next_used_labels = {}
    for _, match in ipairs(labeled) do
      if match.label and match.label:lower() == match.label then
        next_used_labels[pos_id(match.pos, match.win)] = match.label
      end
    end

    return labeled, next_used_labels
  end

  local function render_backdrop(buffer, win)
    local info = visible_window_info(win)
    if not info then
      return
    end

    local max_row = math.min(info.botline, vim.api.nvim_buf_line_count(buffer))
    for row = info.topline, max_row do
      local line = position.line_text(buffer, row)
      vim.api.nvim_buf_set_extmark(buffer, namespace, row - 1, 0, {
        end_row = row - 1,
        end_col = #line,
        hl_group = "HelixFlashBackdrop",
        hl_eol = true,
        strict = false,
        priority = 6000,
      })
    end
  end

  local function render_matches(matches)
    for index, match in ipairs(matches) do
      local buffer = match.buffer
      local end_pos = match.end_pos or match.pos
      local start_row0, start_col = position.before_boundary(buffer, match.pos)
      local end_row0, end_col = position.after_boundary(buffer, end_pos)
      local hl_group = match.current and "HelixFlashCurrent" or (index == 1 and "HelixFlashCurrent" or "HelixFlashTarget")
      local should_highlight = match.highlight
      if should_highlight == nil then
        should_highlight = true
      end

      if should_highlight then
        vim.api.nvim_buf_set_extmark(buffer, namespace, start_row0, start_col, {
          end_row = end_row0,
          end_col = end_col,
          hl_group = hl_group,
          strict = false,
          priority = 6100,
        })
      end

      if match.label then
        vim.api.nvim_buf_set_extmark(buffer, namespace, start_row0, start_col, {
          virt_text = { { match.label, "HelixFlashLabel" } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
          strict = false,
          priority = 6200,
        })
      end
    end
  end

  local function collect_buffers(matches, wins)
    local buffers = {}
    local seen = {}

    for _, win in ipairs(wins) do
      local buffer = vim.api.nvim_win_get_buf(win)
      if not seen[buffer] then
        buffers[#buffers + 1] = buffer
        seen[buffer] = true
      end
    end

    for _, match in ipairs(matches) do
      if not seen[match.buffer] then
        buffers[#buffers + 1] = match.buffer
        seen[match.buffer] = true
      end
    end

    return buffers
  end

  local function render(wins, pattern, matches)
    local buffers = collect_buffers(matches, wins)
    clear(buffers)
    for _, win in ipairs(wins) do
      render_backdrop(vim.api.nvim_win_get_buf(win), win)
    end
    render_matches(matches)
    vim.api.nvim_echo({ { "flash: " .. pattern, "ModeMsg" } }, false, {})
    vim.cmd.redraw()
  end

  local function target_windows(multi_window)
    local current_win = vim.api.nvim_get_current_win()
    if not multi_window then
      return { current_win }
    end

    local wins = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local config = vim.api.nvim_win_get_config(win)
      if config.relative == "" then
        wins[#wins + 1] = win
      end
    end
    return wins
  end

  local function char_pos_from_byte_col0(buffer, row1, byte_col0)
    local line = position.line_text(buffer, row1)
    return { row1, position.char_col_from_byte_col0(line, byte_col0) }
  end

  local function ts_node_range_positions(buffer, node)
    local start_row, start_col, end_row, end_col = node:range()
    local start_pos = char_pos_from_byte_col0(buffer, start_row + 1, start_col)
    local end_boundary = char_pos_from_byte_col0(buffer, end_row + 1, end_col)
    local line_count = vim.api.nvim_buf_line_count(buffer)

    if end_boundary[1] > line_count then
      local last_row = line_count
      return start_pos, { last_row, position.cursor_max_column(buffer, last_row) }
    end

    local end_pos = same_pos(start_pos, end_boundary) and start_pos or position.prev_pos(buffer, end_boundary)
    return start_pos, end_pos
  end

  local function collect_treesitter_matches(win, origin)
    local buffer = vim.api.nvim_win_get_buf(win)
    local line = position.line_text(buffer, origin[1])
    local byte_col0 = position.byte_col0_from_char_col(line, origin[2])
    local ok, parser = pcall(vim.treesitter.get_parser, buffer)
    if not (ok and parser) then
      vim.notify(
        "No treesitter parser for this buffer with filetype=" .. vim.bo[buffer].filetype,
        vim.log.levels.WARN,
        { title = "flash" }
      )
      return {}
    end
    parser:parse()

    local nodes = {}
    parser:for_each_tree(function(tstree, tree)
      if not tstree then
        return
      end

      local node = tree:named_node_for_range({ origin[1] - 1, byte_col0, origin[1] - 1, byte_col0 }, {
        ignore_injections = true,
      })
      while node do
        nodes[#nodes + 1] = node
        node = node:parent()
      end
    end)

    local matches = {}
    local seen = {}
    for _, node in ipairs(nodes) do
      local start_pos, end_pos = ts_node_range_positions(buffer, node)
      local id = range_id(start_pos, end_pos, win)
      if not seen[id] then
        seen[id] = true
        matches[#matches + 1] = {
          win = win,
          buffer = buffer,
          pos = start_pos,
          end_pos = end_pos,
        }
      end
    end

    return matches
  end

  local function assign_treesitter_labels(matches, current_index)
    local labeled = {}
    local labels = vim.split(label_alphabet, "")
    for index, candidate in ipairs(matches) do
      if not labels[index] then
        break
      end

      local match = vim.deepcopy(candidate)
      match.label = labels[index]
      match.current = index == current_index
      match.highlight = match.current
      labeled[#labeled + 1] = match
    end
    return labeled
  end

  local function initial_treesitter_index(matches, current_entry)
    if not current_entry then
      return 1
    end

    for index, match in ipairs(matches) do
      if same_range(current_entry, match.pos, match.end_pos) then
        return math.min(index + 1, #matches)
      end
    end

    return 1
  end

  function flash.pick_visible_word_target(origin, opts)
    opts = opts or {}
    local win = vim.api.nvim_get_current_win()
    local wins = target_windows(opts.multi_window == true)
    local pattern = ""
    local matches = {}
    local used_labels = {}

    render(wins, pattern, matches)

    local ok, result = pcall(function()
      while true do
        local char = getcharstr()
        if not char then
          return nil
        end

        local key = key_code(char)
        if key == "<BS>" or key == "<C-h>" then
          if pattern ~= "" then
            pattern = vim.fn.strcharpart(pattern, 0, vim.fn.strchars(pattern) - 1)
          end
        elseif key == "<CR>" or key == "<Enter>" then
          if #matches > 0 then
            return { win = matches[1].win, buffer = matches[1].buffer, pos = matches[1].pos }
          end
        elseif is_printable_char(char) then
          for _, match in ipairs(matches) do
            if match.label == char then
              return { win = match.win, buffer = match.buffer, pos = match.pos }
            end
          end
          pattern = pattern .. char
        end

        matches, used_labels = assign_labels(collect_visible_matches(wins, win, origin, pattern), pattern, used_labels)
        render(wins, pattern, matches)
      end
    end)

    clear(collect_buffers(matches, wins))
    vim.cmd.redraw()

    if not ok then
      error(result)
    end

    return result
  end

  function flash.pick_treesitter_target(origin, current_entry)
    local win = vim.api.nvim_get_current_win()
    local wins = { win }
    local matches = collect_treesitter_matches(win, origin)
    local current_index = initial_treesitter_index(matches, current_entry)
    if #matches == 0 then
      return nil
    end

    local function redraw()
      render(wins, "treesitter", assign_treesitter_labels(matches, current_index))
    end

    redraw()

    local ok, result = pcall(function()
      while true do
        local char = getcharstr()
        if not char then
          return nil
        end

        local key = key_code(char)
        if key == ";" then
          current_index = math.min(current_index + 1, #matches)
        elseif key == "," then
          current_index = math.max(current_index - 1, 1)
        elseif key == "<CR>" or key == "<Enter>" then
          local current = matches[current_index]
          if current then
            return {
              win = current.win,
              buffer = current.buffer,
              start_pos = current.pos,
              end_pos = current.end_pos,
            }
          end
        elseif is_printable_char(char) then
          for _, match in ipairs(assign_treesitter_labels(matches, current_index)) do
            if match.label == char then
              return {
                win = match.win,
                buffer = match.buffer,
                start_pos = match.pos,
                end_pos = match.end_pos,
              }
            end
          end
        end

        redraw()
      end
    end)

    clear(collect_buffers(assign_treesitter_labels(matches, current_index), wins))
    vim.cmd.redraw()

    if not ok then
      error(result)
    end

    return result
  end

  function flash.clear()
    clear(vim.api.nvim_get_current_buf())
    vim.cmd.redraw()
  end

  return flash
end

return M
