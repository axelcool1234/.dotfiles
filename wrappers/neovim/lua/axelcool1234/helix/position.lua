local M = {}

function M.grapheme_count(text)
  return vim.fn.strchars(text, true)
end

function M.prefix_by_grapheme_count(text, count)
  return vim.fn.strcharpart(text, 0, math.max(count, 0), true)
end

function M.slice_by_grapheme_range(text, start_col, end_col)
  local start_index = math.max(start_col - 1, 0)
  local length = math.max(end_col - start_col + 1, 0)
  return vim.fn.strcharpart(text, start_index, length, true)
end

function M.suffix_from_grapheme_col(text, start_col)
  local total = M.grapheme_count(text)
  if start_col > total then
    return ""
  end

  return vim.fn.strcharpart(text, math.max(start_col - 1, 0), total, true)
end

function M.grapheme_at(text, col)
  local total = M.grapheme_count(text)
  if col < 1 or col > total then
    return nil
  end

  return vim.fn.strcharpart(text, col - 1, 1, true)
end

function M.byte_col0_from_grapheme_col(text, col)
  local clamped = math.max(1, math.min(col, M.grapheme_count(text) + 1))
  if clamped <= 1 then
    return 0
  end

  local byte_index = vim.fn.byteidx(text, clamped - 1)
  return byte_index < 0 and #text or byte_index
end

function M.grapheme_col_from_byte_col0(text, byte_col0)
  local clamped = math.max(0, math.min(byte_col0, #text))
  return vim.fn.charidx(text, clamped) + 1
end

-- Logical points in the Helix layer are gaps between text elements. A
-- boundary is 1-indexed by row and 0-indexed by grapheme column. Unlike a
-- Neovim cursor position it never contains a byte column, and unlike the
-- legacy cell position it does not need a synthetic newline cell.
function M.boundary(row, col0)
  return { row = row, col = col0 }
end

function M.copy_boundary(point)
  return M.boundary(point.row, point.col)
end

function M.compare_boundaries(left, right)
  if left.row ~= right.row then
    return left.row < right.row and -1 or 1
  end
  if left.col ~= right.col then
    return left.col < right.col and -1 or 1
  end
  return 0
end

function M.boundaries_equal(left, right)
  return M.compare_boundaries(left, right) == 0
end

function M.display_col_from_grapheme_col(text, col)
  return vim.fn.strdisplaywidth(M.prefix_by_grapheme_count(text, math.max(col - 1, 0))) + 1
end

function M.grapheme_col_from_display_col(text, display_col)
  local target = math.max(display_col, 1)
  local total = M.grapheme_count(text)

  for col = 1, total do
    local start_display_col = M.display_col_from_grapheme_col(text, col)
    local next_display_col = M.display_col_from_grapheme_col(text, col + 1)
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
  return M.display_col_from_grapheme_col(M.line_text(buffer, clamped[1]), clamped[2])
end

function M.grapheme_col_at_display_col(buffer, row, display_col)
  return M.grapheme_col_from_display_col(M.line_text(buffer, row), display_col)
end

function M.line_count(buffer)
  return vim.api.nvim_buf_line_count(buffer)
end

function M.line_text(buffer, row)
  return vim.api.nvim_buf_get_lines(buffer, row - 1, row, false)[1] or ""
end

function M.text_end_column(buffer, row)
  return math.max(M.grapheme_count(M.line_text(buffer, row)), 1)
end

function M.cursor_max_column(buffer, row)
  return M.grapheme_count(M.line_text(buffer, row)) + 1
end

function M.clamp_pos(buffer, pos)
  local row = math.max(1, math.min(pos[1], M.line_count(buffer)))
  local col = math.max(1, math.min(pos[2], M.cursor_max_column(buffer, row)))
  return { row, col }
end

function M.clamp_boundary(buffer, point)
  local row = math.max(1, math.min(point.row, M.line_count(buffer)))
  local col = math.max(0, math.min(point.col, M.grapheme_count(M.line_text(buffer, row))))
  return M.boundary(row, col)
end

function M.boundary_before_cell(buffer, pos)
  local clamped = M.clamp_pos(buffer, pos)
  return M.boundary(clamped[1], clamped[2] - 1)
end

function M.boundary_after_cell(buffer, pos)
  local clamped = M.clamp_pos(buffer, pos)
  if M.is_newline_pos(buffer, clamped) then
    return M.boundary(clamped[1] + 1, 0)
  end

  local line = M.line_text(buffer, clamped[1])
  return M.boundary(clamped[1], math.min(clamped[2], M.grapheme_count(line)))
end

function M.cell_after_boundary(buffer, point)
  local clamped = M.clamp_boundary(buffer, point)
  local count = M.grapheme_count(M.line_text(buffer, clamped.row))
  if clamped.col < count then
    return { clamped.row, clamped.col + 1 }
  end
  return { clamped.row, count + 1 }
end

function M.cell_before_boundary(buffer, point)
  local clamped = M.clamp_boundary(buffer, point)
  if clamped.col > 0 then
    return { clamped.row, clamped.col }
  end
  if clamped.row > 1 then
    return { clamped.row - 1, M.cursor_max_column(buffer, clamped.row - 1) }
  end
  return { 1, 1 }
end

function M.boundary_to_byte(buffer, point)
  local clamped = M.clamp_boundary(buffer, point)
  local line = M.line_text(buffer, clamped.row)
  return clamped.row - 1, M.byte_col0_from_grapheme_col(line, clamped.col + 1)
end

function M.boundary_from_byte(buffer, row0, byte_col0)
  local line_count = M.line_count(buffer)
  if row0 >= line_count then
    local last_line = M.line_text(buffer, line_count)
    return M.boundary(line_count, M.grapheme_count(last_line))
  end

  local row = math.max(1, row0 + 1)
  local line = M.line_text(buffer, row)
  return M.boundary(row, M.grapheme_col_from_byte_col0(line, byte_col0) - 1)
end

function M.supports_column(buffer, row, col)
  return row >= 1 and row <= M.line_count(buffer) and col >= 1 and col <= M.cursor_max_column(buffer, row)
end

function M.is_newline_pos(buffer, pos)
  local clamped = M.clamp_pos(buffer, pos)
  return clamped[1] < M.line_count(buffer) and clamped[2] == M.cursor_max_column(buffer, clamped[1])
end

function M.byte_before_cell(buffer, pos)
  return M.boundary_to_byte(buffer, M.boundary_before_cell(buffer, pos))
end

function M.byte_after_cell(buffer, pos)
  return M.boundary_to_byte(buffer, M.boundary_after_cell(buffer, pos))
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
