local M = {}

function M.line_count(buffer)
  return vim.api.nvim_buf_line_count(buffer)
end

function M.line_text(buffer, row)
  return vim.api.nvim_buf_get_lines(buffer, row - 1, row, false)[1] or ""
end

function M.text_end_column(buffer, row)
  return math.max(#M.line_text(buffer, row), 1)
end

function M.cursor_max_column(buffer, row)
  return #M.line_text(buffer, row) + 1
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

  return row - 1, math.min(col - 1, #line)
end

function M.after_boundary(buffer, pos)
  local clamped = M.clamp_pos(buffer, pos)
  local row = clamped[1]
  local col = clamped[2]
  local line = M.line_text(buffer, row)

  if M.is_newline_pos(buffer, clamped) then
    return row, 0
  end

  return row - 1, math.min(col, #line)
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
