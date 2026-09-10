local M = {}

function M.char_count(text)
  return vim.fn.strchars(text, true)
end

function M.byte_length(text)
  return #text
end

function M.prefix_by_char_count(text, count)
  return vim.fn.strcharpart(text, 0, math.max(count, 0), true)
end

function M.slice_by_char_range(text, start_col, end_col)
  local start_index = math.max(start_col - 1, 0)
  local length = math.max(end_col - start_col + 1, 0)
  return vim.fn.strcharpart(text, start_index, length, true)
end

function M.suffix_from_char_col(text, start_col)
  local total = M.char_count(text)
  if start_col > total then
    return ""
  end

  return vim.fn.strcharpart(text, math.max(start_col - 1, 0), total, true)
end

function M.char_at(text, col)
  local total = M.char_count(text)
  if col < 1 or col > total then
    return nil
  end

  return vim.fn.strcharpart(text, col - 1, 1, true)
end

function M.byte_col0_from_char_col(text, col)
  local clamped = math.max(1, math.min(col, M.char_count(text) + 1))
  if clamped <= 1 then
    return 0
  end

  local byte_index = vim.fn.byteidx(text, clamped - 1)
  return byte_index < 0 and #text or byte_index
end

function M.char_col_from_byte_col0(text, byte_col0)
  local clamped = math.max(0, math.min(byte_col0, #text))
  return vim.fn.charidx(text, clamped) + 1
end

function M.display_col_from_char_col(text, col)
  return vim.fn.strdisplaywidth(M.prefix_by_char_count(text, math.max(col - 1, 0))) + 1
end

function M.char_col_from_display_col(text, display_col)
  local target = math.max(display_col, 1)
  local total = M.char_count(text)

  for col = 1, total do
    local start_display_col = M.display_col_from_char_col(text, col)
    local next_display_col = M.display_col_from_char_col(text, col + 1)
    if target < next_display_col then
      return col
    end
    if target == start_display_col then
      return col
    end
  end

  return total + 1
end

function M.display_col(buffer, pos)
  local clamped = M.clamp_pos(buffer, pos)
  return M.display_col_from_char_col(M.line_text(buffer, clamped[1]), clamped[2])
end

function M.char_col_at_display_col(buffer, row, display_col)
  return M.char_col_from_display_col(M.line_text(buffer, row), display_col)
end

function M.line_count(buffer)
  return vim.api.nvim_buf_line_count(buffer)
end

function M.line_text(buffer, row)
  return vim.api.nvim_buf_get_lines(buffer, row - 1, row, false)[1] or ""
end

function M.text_end_column(buffer, row)
  return math.max(M.char_count(M.line_text(buffer, row)), 1)
end

function M.cursor_max_column(buffer, row)
  return M.char_count(M.line_text(buffer, row)) + 1
end

function M.clamp_pos(buffer, pos)
  local row = math.max(1, math.min(pos[1], M.line_count(buffer)))
  local col = math.max(1, math.min(pos[2], M.cursor_max_column(buffer, row)))
  return { row, col }
end

function M.supports_column(buffer, row, col)
  return row >= 1 and row <= M.line_count(buffer) and col >= 1 and col <= M.cursor_max_column(buffer, row)
end

function M.is_newline_pos(buffer, pos)
  local clamped = M.clamp_pos(buffer, pos)
  return clamped[1] < M.line_count(buffer) and clamped[2] == M.cursor_max_column(buffer, clamped[1])
end

function M.before_boundary(buffer, pos)
  local clamped = M.clamp_pos(buffer, pos)
  local row = clamped[1]
  local col = clamped[2]
  local line = M.line_text(buffer, row)

  if M.is_newline_pos(buffer, clamped) then
    return row - 1, #line
  end

  return row - 1, M.byte_col0_from_char_col(line, col)
end

function M.after_boundary(buffer, pos)
  local clamped = M.clamp_pos(buffer, pos)
  local row = clamped[1]
  local col = clamped[2]
  local line = M.line_text(buffer, row)

  if M.is_newline_pos(buffer, clamped) then
    return row, 0
  end

  return row - 1, M.byte_col0_from_char_col(line, col + 1)
end

function M.next_pos(buffer, pos)
  local clamped = M.clamp_pos(buffer, pos)
  local row = clamped[1]
  local col = clamped[2]
  local max_col = M.cursor_max_column(buffer, row)

  if col < max_col then
    return { row, col + 1 }
  end

  if row < M.line_count(buffer) then
    return { row + 1, 1 }
  end

  return clamped
end

function M.prev_pos(buffer, pos)
  local clamped = M.clamp_pos(buffer, pos)
  local row = clamped[1]
  local col = clamped[2]

  if col > 1 then
    return { row, col - 1 }
  end

  if row <= 1 then
    return clamped
  end

  return { row - 1, M.cursor_max_column(buffer, row - 1) }
end

return M
