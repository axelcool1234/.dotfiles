local position = require("axelcool1234.helix.position")

local M = {}
local Range = {}
local buffers = setmetatable({}, { __mode = "k" })

local function copy_cell(cell)
  return { cell[1], cell[2] }
end

local function buffer_for(range)
  local buffer = buffers[range]
  if buffer and vim.api.nvim_buf_is_valid(buffer) then
    return buffer
  end
  return vim.api.nvim_get_current_buf()
end

local function direction(range)
  if range.point then
    return 0
  end
  return -position.compare_boundaries(range.anchor, range.head)
end

function Range:copy()
  return M.from_boundaries(buffer_for(self), self.anchor, self.head, {
    point = self.point,
    goal_display_col = self.goal_display_col,
    visual_cursor = self.visual_cursor and copy_cell(self.visual_cursor) or nil,
    visual_anchor = self.visual_anchor and copy_cell(self.visual_anchor) or nil,
  })
end

function Range:buffer_id()
  return buffer_for(self)
end

function Range:direction()
  return direction(self)
end

function Range:is_empty()
  return position.boundaries_equal(self.anchor, self.head)
end

function Range:from()
  if position.compare_boundaries(self.anchor, self.head) <= 0 then
    return position.copy_boundary(self.anchor)
  end
  return position.copy_boundary(self.head)
end

function Range:to()
  if position.compare_boundaries(self.anchor, self.head) <= 0 then
    return position.copy_boundary(self.head)
  end
  return position.copy_boundary(self.anchor)
end

function Range:cursor()
  local buffer = buffer_for(self)
  if self.visual_cursor then
    return copy_cell(self.visual_cursor)
  end
  if self:is_empty() then
    return position.cell_after_boundary(buffer, self.head)
  end
  if direction(self) < 0 then
    return position.cell_after_boundary(buffer, self.head)
  end
  return position.cell_before_boundary(buffer, self.head)
end

function Range:anchor_cell()
  local buffer = buffer_for(self)
  if self.visual_anchor then
    return copy_cell(self.visual_anchor)
  end
  if self:is_empty() then
    return self:cursor()
  end
  if direction(self) < 0 then
    return position.cell_before_boundary(buffer, self.anchor)
  end
  return position.cell_after_boundary(buffer, self.anchor)
end

function Range:reversed()
  return M.from_boundaries(buffer_for(self), self.head, self.anchor, {
    point = self.point,
    goal_display_col = self.goal_display_col,
    visual_cursor = self.visual_anchor,
    visual_anchor = self.visual_cursor,
  })
end

function Range:start_cell()
  return position.cell_after_boundary(buffer_for(self), self:from())
end

function Range:end_cell()
  if self:is_empty() then
    return self:start_cell()
  end
  return position.cell_before_boundary(buffer_for(self), self:to())
end

function Range:byte_range()
  local buffer = buffer_for(self)
  local from = self:from()
  local to = self:to()
  local start_row, start_col = position.boundary_to_byte(buffer, from)
  local end_row, end_col = position.boundary_to_byte(buffer, to)
  return start_row, start_col, end_row, end_col
end

function Range:text()
  local buffer = buffer_for(self)
  local start_row, start_col, end_row, end_col = self:byte_range()
  local pieces = vim.api.nvim_buf_get_text(buffer, start_row, start_col, end_row, end_col, {})
  return table.concat(pieces, "\n")
end

function Range:overlaps(other)
  local left_from, left_to = self:from(), self:to()
  local right_from, right_to = other:from(), other:to()
  if self:is_empty() or other:is_empty() then
    return position.boundaries_equal(left_from, right_from)
  end
  return position.compare_boundaries(left_from, right_to) < 0
    and position.compare_boundaries(right_from, left_to) < 0
end

function Range:merge(other, prefer_self)
  local from = position.compare_boundaries(self:from(), other:from()) <= 0 and self:from() or other:from()
  local to = position.compare_boundaries(self:to(), other:to()) >= 0 and self:to() or other:to()
  local source = prefer_self and self or other
  local backward = source:direction() < 0
  local merged = backward and M.from_boundaries(buffer_for(self), to, from)
    or M.from_boundaries(buffer_for(self), from, to)
  merged.goal_display_col = source.goal_display_col
  merged.visual_cursor = source.visual_cursor and copy_cell(source.visual_cursor) or nil
  return merged
end

function Range:as_selection()
  self.point = false
  return self
end

local metatable = { __index = Range }

function M.is_range(value)
  return getmetatable(value) == metatable
end

function M.from_boundaries(buffer, anchor, head, opts)
  opts = opts or {}
  local range = {
    anchor = position.clamp_boundary(buffer, anchor),
    head = position.clamp_boundary(buffer, head),
    point = opts.point == true,
    goal_display_col = opts.goal_display_col,
    visual_cursor = opts.visual_cursor and copy_cell(opts.visual_cursor) or nil,
    visual_anchor = opts.visual_anchor and copy_cell(opts.visual_anchor) or nil,
  }
  setmetatable(range, metatable)
  buffers[range] = buffer
  return range
end

function M.from_cells(buffer, anchor_cell, cursor_cell, opts)
  opts = opts or {}
  local anchor = position.clamp_pos(buffer, anchor_cell)
  local cursor = position.clamp_pos(buffer, cursor_cell)
  local before = anchor[1] < cursor[1] or (anchor[1] == cursor[1] and anchor[2] < cursor[2])
  local after = anchor[1] > cursor[1] or (anchor[1] == cursor[1] and anchor[2] > cursor[2])

  if opts.empty == true then
    local boundary = position.boundary_before_cell(buffer, cursor)
    return M.from_boundaries(buffer, boundary, boundary, opts)
  end
  if after then
    return M.from_boundaries(
      buffer,
      position.boundary_after_cell(buffer, anchor),
      position.boundary_before_cell(buffer, cursor),
      opts
    )
  end

  opts.point = opts.point ~= false and not before
  return M.from_boundaries(
    buffer,
    position.boundary_before_cell(buffer, anchor),
    position.boundary_after_cell(buffer, cursor),
    opts
  )
end

function M.from_byte_range(buffer, start_row0, start_col0, end_row0, end_col0, opts)
  local from = position.boundary_from_byte(buffer, start_row0, start_col0)
  local to = position.boundary_from_byte(buffer, end_row0, end_col0)
  opts = opts or {}
  if opts.backward == true then
    return M.from_boundaries(buffer, to, from, opts)
  end
  return M.from_boundaries(buffer, from, to, opts)
end

function M.copy(buffer, range)
  assert(M.is_range(range), "expected a Range")
  return M.from_boundaries(buffer, range.anchor, range.head, {
    point = range.point,
    goal_display_col = range.goal_display_col,
    visual_cursor = range.visual_cursor,
    visual_anchor = range.visual_anchor,
  })
end

return M
