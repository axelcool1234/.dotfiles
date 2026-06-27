local M = {}

local label_alphabet = "asdfjklghqwertyuiopzxcvbnmASDFJKLGHQWERTYUIOPZXCVBNM"

local function setup_highlights()
  vim.api.nvim_set_hl(0, "HelixFlashLabel", { link = "Substitute", default = true })
  vim.api.nvim_set_hl(0, "HelixFlashTarget", { link = "Search", default = true })
  vim.api.nvim_set_hl(0, "HelixFlashBackdrop", { link = "Comment", default = true })
end

local function same_pos(left, right)
  return left[1] == right[1] and left[2] == right[2]
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

  local function clear(buffer)
    if buffer and vim.api.nvim_buf_is_valid(buffer) then
      vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
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

  local function collect_visible_matches(buffer, win, origin, pattern)
    local info = visible_window_info(win)
    if not info then
      return {}
    end

    local compiled = compile_exact_pattern(pattern)
    if not compiled then
      return {}
    end

    local max_row = math.min(info.botline, vim.api.nvim_buf_line_count(buffer))
    local width = math.max(vim.api.nvim_win_get_width(win), 1)
    local matches = {}

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
        if not same_pos(target_pos, origin) then
          matches[#matches + 1] = {
            pos = target_pos,
            text = text,
            next_char = position.char_at(line, position.char_col_from_byte_col0(line, end_byte)),
            distance = math.abs(row - origin[1]) * width + math.abs(char_col - origin[2]),
          }
        end

        byteidx = math.max(end_byte, start_byte + 1)
      end
    end

    table.sort(matches, function(left, right)
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

  local function assign_labels(matches, pattern)
    local labels = vim.split(label_alphabet, "")
    local disallowed = next_chars_for_matches(matches, pattern)
    local available = {}

    for _, label in ipairs(labels) do
      if not disallowed[smart_case_fold(label, pattern)] then
        available[#available + 1] = label
      end
    end

    local labeled = {}
    for index = 1, math.min(#matches, #available) do
      local match = vim.deepcopy(matches[index])
      match.label = available[index]
      labeled[index] = match
    end
    return labeled
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

  local function render_matches(buffer, matches)
    for _, match in ipairs(matches) do
      local row = match.pos[1]
      local col = match.pos[2]
      local line = position.line_text(buffer, row)
      local start_col = position.byte_col0_from_char_col(line, col)
      local end_col = position.byte_col0_from_char_col(line, col + 1)

      vim.api.nvim_buf_set_extmark(buffer, namespace, row - 1, start_col, {
        end_col = end_col,
        hl_group = "HelixFlashTarget",
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

  local function render(buffer, win, pattern, matches)
    clear(buffer)
    render_backdrop(buffer, win)
    render_matches(buffer, matches)
    vim.api.nvim_echo({ { "flash: " .. pattern, "ModeMsg" } }, false, {})
    vim.cmd.redraw()
  end

  function flash.pick_visible_word_target(origin)
    local buffer = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    local pattern = ""
    local matches = {}

    render(buffer, win, pattern, matches)

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
            return matches[1].pos
          end
        elseif is_printable_char(char) then
          for _, match in ipairs(matches) do
            if match.label == char then
              return match.pos
            end
          end
          pattern = pattern .. char
        end

        matches = assign_labels(collect_visible_matches(buffer, win, origin, pattern), pattern)
        render(buffer, win, pattern, matches)
      end
    end)

    clear(buffer)
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
