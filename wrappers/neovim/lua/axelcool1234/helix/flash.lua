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

local function pos_id(pos, win)
  return string.format("%d:%d:%d", win or 0, pos[1], pos[2])
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
      local row = match.pos[1]
      local col = match.pos[2]
      local line = position.line_text(buffer, row)
      local start_col = position.byte_col0_from_char_col(line, col)
      local end_col = position.byte_col0_from_char_col(line, col + 1)
      local hl_group = index == 1 and "HelixFlashCurrent" or "HelixFlashTarget"

      vim.api.nvim_buf_set_extmark(buffer, namespace, row - 1, start_col, {
        end_col = end_col,
        hl_group = hl_group,
        strict = false,
        priority = 6100,
      })

      if match.label then
        vim.api.nvim_buf_set_extmark(buffer, namespace, row - 1, start_col, {
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

  function flash.clear()
    clear(vim.api.nvim_get_current_buf())
    vim.cmd.redraw()
  end

  return flash
end

return M
