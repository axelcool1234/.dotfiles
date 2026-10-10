local position = require("axelcool1234.helix.position")
local range_module = require("axelcool1234.helix.range")
local selection_module = require("axelcool1234.helix.selection")

local M = {}
local Transaction = {}
Transaction.__index = Transaction
local Tracker = {}
Tracker.__index = Tracker

local affinity_gravity = {
  before = false,
  before_sticky = false,
  after = true,
  after_sticky = true,
}

local function replacement_lines(text)
  if type(text) == "table" then
    return text
  end
  if text == nil or text == "" then
    return {}
  end
  return vim.split(text, "\n", { plain = true })
end

local function point_mark(buffer, namespace, point, affinity)
  local row, col = position.boundary_to_byte(buffer, point)
  return vim.api.nvim_buf_set_extmark(buffer, namespace, row, col, {
    right_gravity = affinity_gravity[affinity] ~= false,
  })
end

local function resolve_mark(buffer, namespace, mark)
  local byte_pos = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, mark, {})
  if #byte_pos == 0 then
    return nil
  end
  return position.boundary_from_byte(buffer, byte_pos[1], byte_pos[2])
end

local endpoint_affinities = {
  -- Include text inserted at either edge of the range.
  outside = { from = "before_sticky", to = "after_sticky" },
  -- Exclude text inserted immediately outside the range.
  inside = { from = "after_sticky", to = "before_sticky" },
  -- Keep both endpoints on the same side of an insertion.
  before = { from = "before_sticky", to = "before_sticky" },
  after = { from = "after_sticky", to = "after_sticky" },
}

local function track_marks(buffer, namespace, range, mode, affinity)
  if range:is_empty() and mode == "span" then
    return {
      from = point_mark(buffer, namespace, range.head, "before_sticky"),
      to = point_mark(buffer, namespace, range.head, "after_sticky"),
      direction = 1,
      kind = range.kind,
    }
  end
  if range:is_empty() then
    local edge = endpoint_affinities[affinity or "outside"] or endpoint_affinities.outside
    local mark = point_mark(buffer, namespace, range.head, edge.to)
    local marks = {
      from = mark,
      to = mark,
      direction = 0,
      kind = range.kind,
      goal_display_col = range.goal_display_col,
    }
    if range.visual_cursor then
      marks.visual_cursor = point_mark(buffer, namespace, position.boundary_before_cell(buffer, range.visual_cursor), "after_sticky")
    end
    if range.visual_anchor then
      marks.visual_anchor = point_mark(buffer, namespace, position.boundary_before_cell(buffer, range.visual_anchor), "after_sticky")
    end
    return marks
  end
  local edges = endpoint_affinities[affinity or "outside"] or endpoint_affinities.outside
  local marks = {
    from = point_mark(buffer, namespace, range:from(), edges.from),
    to = point_mark(buffer, namespace, range:to(), edges.to),
    direction = range:direction(),
    kind = range.kind,
    goal_display_col = range.goal_display_col,
  }
  if range.visual_cursor then
    marks.visual_cursor = point_mark(buffer, namespace, position.boundary_before_cell(buffer, range.visual_cursor), "after_sticky")
  end
  if range.visual_anchor then
    marks.visual_anchor = point_mark(buffer, namespace, position.boundary_before_cell(buffer, range.visual_anchor), "after_sticky")
  end
  return marks
end

local function range_from_marks(buffer, namespace, marks)
  local from = resolve_mark(buffer, namespace, marks.from)
  local to = resolve_mark(buffer, namespace, marks.to)
  if not from or not to then
    return nil
  end
  local visual_cursor
  if marks.visual_cursor then
    local boundary = resolve_mark(buffer, namespace, marks.visual_cursor)
    if not boundary then
      return nil
    end
    visual_cursor = position.cell_after_boundary(buffer, boundary)
  end
  local visual_anchor
  if marks.visual_anchor then
    local boundary = resolve_mark(buffer, namespace, marks.visual_anchor)
    if not boundary then
      return nil
    end
    visual_anchor = position.cell_after_boundary(buffer, boundary)
  end
  if marks.direction < 0 then
    return range_module.from_boundaries(buffer, to, from, {
      goal_display_col = marks.goal_display_col,
      kind = marks.kind,
      visual_cursor = visual_cursor,
      visual_anchor = visual_anchor,
    })
  end
  return range_module.from_boundaries(buffer, from, to, {
    goal_display_col = marks.goal_display_col,
    kind = marks.kind,
    visual_cursor = visual_cursor,
    visual_anchor = visual_anchor,
  })
end

function Tracker:resolve(opts)
  opts = opts or {}
  local ranges = {}
  for index, marks in ipairs(self.marks) do
    local range = range_from_marks(self.buffer, self.namespace, marks)
    if not range and opts.strict == true then
      return nil
    end
    ranges[index] = range or self.ranges[index]:copy()
  end
  if opts.keep ~= true then
    self:clear()
  end
  return ranges
end

function Tracker:resolve_selection(opts)
  assert(self.primary_index, "range tracker does not represent a Selection")
  local ranges = self:resolve(opts)
  if not ranges then
    return nil
  end
  return selection_module.new(self.buffer, ranges, self.primary_index)
end

function Tracker:clear()
  if self.cleared then
    return
  end
  for _, marks in ipairs(self.marks) do
    pcall(vim.api.nvim_buf_del_extmark, self.buffer, self.namespace, marks.from)
    if marks.to ~= marks.from then
      pcall(vim.api.nvim_buf_del_extmark, self.buffer, self.namespace, marks.to)
    end
    if marks.visual_cursor then
      pcall(vim.api.nvim_buf_del_extmark, self.buffer, self.namespace, marks.visual_cursor)
    end
    if marks.visual_anchor then
      pcall(vim.api.nvim_buf_del_extmark, self.buffer, self.namespace, marks.visual_anchor)
    end
  end
  self.cleared = true
end

local function edit_starts_before(left, right)
  local comparison = position.compare_boundaries(left.range:from(), right.range:from())
  if comparison ~= 0 then
    return comparison < 0
  end
  return position.compare_boundaries(left.range:to(), right.range:to()) < 0
end

local function validate_edits(edits)
  table.sort(edits, edit_starts_before)
  local previous
  for _, edit in ipairs(edits) do
    if previous and position.compare_boundaries(previous.range:to(), edit.range:from()) > 0 then
      error("transaction edits must be ordered and non-overlapping")
    end
    previous = edit
  end
end

function Transaction:replace(range, replacement)
  self.edits[#self.edits + 1] = {
    range = range_module.copy(self.buffer, range),
    replacement = replacement_lines(replacement),
  }
  return self
end

-- Adapter for byte-oriented editor APIs (Tree-sitter, LSP and option-derived
-- delimiters). Bytes enter the model here and are converted immediately.
function Transaction:replace_bytes(start_row0, start_col0, end_row0, end_col0, replacement)
  return self:replace(range_module.from_byte_range(self.buffer, start_row0, start_col0, end_row0, end_col0), replacement)
end

function Transaction:insert(point, text)
  local range = range_module.from_boundaries(self.buffer, point, point)
  return self:replace(range, text)
end

function Transaction:track_range(range, opts)
  opts = opts or {}
  self.tracked_ranges[#self.tracked_ranges + 1] = {
    range = range_module.copy(self.buffer, range),
    mode = "range",
    affinity = opts.affinity or "outside",
  }
  return #self.tracked_ranges
end

function Transaction:track_insertion(point)
  self.tracked_ranges[#self.tracked_ranges + 1] = {
    range = range_module.from_boundaries(self.buffer, point, point),
    mode = "span",
  }
  return #self.tracked_ranges
end

function Transaction:track_selection(selection, opts)
  assert(selection.buffer == self.buffer, "transaction and selection buffers must match")
  assert(self.tracked_selection == nil, "a transaction can track only one resulting selection")
  assert(self.result_selection == nil, "a transaction cannot track and explicitly set its resulting selection")
  local first = #self.tracked_ranges + 1
  for _, range in ipairs(selection.ranges) do
    self:track_range(range, opts)
  end
  self.tracked_selection = {
    first = first,
    count = #selection.ranges,
    primary_index = selection.primary_index,
  }
  return self
end

-- Set a selection whose coordinates already describe the post-edit buffer.
function Transaction:with_selection(selection)
  assert(selection.buffer == self.buffer, "transaction and selection buffers must match")
  assert(self.tracked_selection == nil, "a transaction cannot track and explicitly set its resulting selection")
  self.result_selection = selection:copy()
  return self
end

function Transaction:apply()
  validate_edits(self.edits)
  local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-transaction")
  vim.api.nvim_buf_clear_namespace(self.buffer, namespace, 0, -1)

  local tracked_marks = {}
  for index, tracked in ipairs(self.tracked_ranges) do
    tracked_marks[index] = track_marks(self.buffer, namespace, tracked.range, tracked.mode, tracked.affinity)
  end

  for index = #self.edits, 1, -1 do
    local edit = self.edits[index]
    local start_row, start_col, end_row, end_col = edit.range:byte_range()
    vim.api.nvim_buf_set_text(self.buffer, start_row, start_col, end_row, end_col, edit.replacement)
  end

  local ranges = {}
  for index, marks in ipairs(tracked_marks) do
    ranges[index] = range_from_marks(self.buffer, namespace, marks)
  end

  local selection = self.result_selection and self.result_selection:copy() or nil
  if self.tracked_selection then
    local tracked = {}
    for index = 1, self.tracked_selection.count do
      tracked[index] = ranges[self.tracked_selection.first + index - 1]
    end
    selection = selection_module.new(self.buffer, tracked, self.tracked_selection.primary_index)
  end

  vim.api.nvim_buf_clear_namespace(self.buffer, namespace, 0, -1)
  return { ranges = ranges, selection = selection }
end

function M.new(buffer)
  return setmetatable({
    buffer = buffer,
    edits = {},
    tracked_ranges = {},
    tracked_selection = nil,
    result_selection = nil,
  }, Transaction)
end

-- Track logical ranges across edits performed outside Transaction. This is the
-- only escape hatch needed for editor commands and LSP formatting that mutate
-- the buffer themselves; callers still work entirely in logical coordinates.
function M.track_ranges(buffer, ranges, opts)
  opts = opts or {}
  local namespace = vim.api.nvim_create_namespace("axelcool1234-helix-range-tracker")
  local tracker = setmetatable({
    buffer = buffer,
    namespace = namespace,
    ranges = {},
    marks = {},
    cleared = false,
  }, Tracker)
  for index, range in ipairs(ranges) do
    local logical = range_module.copy(buffer, range)
    tracker.ranges[index] = logical
    tracker.marks[index] = track_marks(buffer, namespace, logical, "range", opts.affinity or "outside")
  end
  return tracker
end

function M.track_selection(selection, opts)
  local tracker = M.track_ranges(selection.buffer, selection.ranges, opts)
  tracker.primary_index = selection.primary_index
  return tracker
end

M.affinity_gravity = affinity_gravity
M.endpoint_affinities = endpoint_affinities

return M
