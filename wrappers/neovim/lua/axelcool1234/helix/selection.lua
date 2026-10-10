local position = require("axelcool1234.helix.position")
local range_module = require("axelcool1234.helix.range")

local M = {}
local Selection = {}
Selection.__index = Selection

local function sort_ranges(ranges)
  table.sort(ranges, function(left, right)
    local start_cmp = position.compare_boundaries(left:from(), right:from())
    if start_cmp ~= 0 then
      return start_cmp < 0
    end
    return position.compare_boundaries(left:to(), right:to()) < 0
  end)
end

function Selection:copy()
  local ranges = {}
  for index, range in ipairs(self.ranges) do
    ranges[index] = range:copy()
  end
  return M.new(self.buffer, ranges, self.primary_index)
end

function Selection:primary()
  return self.ranges[self.primary_index]
end

function Selection:len()
  return #self.ranges
end

function Selection:into_single()
  return M.single(self.buffer, self:primary())
end

function Selection:select_cursor_cells()
  return self:transform(function(range)
    return range:as_selection()
  end)
end

function Selection:transform(transform)
  local ranges = {}
  local primary
  for index, range in ipairs(self.ranges) do
    ranges[index] = transform(range:copy(), index)
    assert(range_module.is_range(ranges[index]), "selection transform must return a Range")
    if index == self.primary_index then
      primary = ranges[index]
    end
  end
  return M.new(self.buffer, ranges, self.primary_index, primary)
end

function Selection:transform_iter(transform)
  local ranges = {}
  local primary
  for index, range in ipairs(self.ranges) do
    local produced = transform(range:copy(), index) or {}
    for _, next_range in ipairs(produced) do
      assert(range_module.is_range(next_range), "selection transform_iter must return Ranges")
      ranges[#ranges + 1] = next_range
      if index == self.primary_index and not primary then
        primary = next_range
      end
    end
  end
  assert(#ranges > 0, "a selection transform cannot remove every range")
  return M.new(self.buffer, ranges, 1, primary or ranges[1])
end

function Selection:replace(index, range)
  assert(range_module.is_range(range), "expected a Range")
  local ranges = {}
  for range_index, existing in ipairs(self.ranges) do
    ranges[range_index] = range_index == index and range or existing
  end
  return M.new(self.buffer, ranges, self.primary_index, ranges[self.primary_index])
end

function Selection:push(range, make_primary)
  assert(range_module.is_range(range), "expected a Range")
  local ranges = vim.list_extend({}, self.ranges)
  ranges[#ranges + 1] = range
  local primary = make_primary == true and range or ranges[self.primary_index]
  return M.new(self.buffer, ranges, self.primary_index, primary)
end

function Selection:remove(index)
  assert(#self.ranges > 1, "cannot remove the last range from a selection")
  local ranges = {}
  local primary = self:primary()
  for range_index, range in ipairs(self.ranges) do
    if range_index ~= index then
      ranges[#ranges + 1] = range
    end
  end
  if index == self.primary_index then
    primary = ranges[math.min(index, #ranges)]
  end
  return M.new(self.buffer, ranges, 1, primary)
end

function Selection:filter(predicate)
  local ranges = {}
  local primary
  local previous
  for index, range in ipairs(self.ranges) do
    if predicate(range:copy(), index) then
      ranges[#ranges + 1] = range
      if index == self.primary_index then
        primary = range
      elseif index < self.primary_index then
        previous = range
      end
    end
  end
  if #ranges == 0 then
    return nil
  end
  primary = primary or previous or ranges[1]
  return M.new(self.buffer, ranges, 1, primary)
end

function Selection:texts()
  local texts = {}
  for index, range in ipairs(self.ranges) do
    texts[index] = range:text()
  end
  return texts
end

function Selection:normalize(primary_range)
  if #self.ranges == 0 then
    return self
  end

  primary_range = primary_range or self.ranges[self.primary_index]
  sort_ranges(self.ranges)
  local normalized = {}
  local normalized_primary = 1

  for _, range in ipairs(self.ranges) do
    local previous = normalized[#normalized]
    if previous and previous:overlaps(range) then
      local keep_previous = previous == primary_range
      normalized[#normalized] = previous:merge(range, keep_previous)
      if previous == primary_range or range == primary_range then
        primary_range = normalized[#normalized]
        normalized_primary = #normalized
      end
    else
      normalized[#normalized + 1] = range
      if range == primary_range then
        normalized_primary = #normalized
      end
    end
  end

  self.ranges = normalized
  self.primary_index = normalized_primary
  return self
end

function M.new(buffer, ranges, primary_index, primary_range)
  assert(#ranges > 0, "a selection must contain at least one range")
  local copied = {}
  local original_primary = primary_range or ranges[primary_index or 1]
  local primary
  for index, range in ipairs(ranges) do
    copied[index] = range_module.copy(buffer, range)
    if range == original_primary then
      primary = copied[index]
    end
  end
  local selection = setmetatable({
    buffer = buffer,
    ranges = copied,
    primary_index = primary_index or 1,
  }, Selection)
  return selection:normalize(primary)
end

function M.single(buffer, range)
  return M.new(buffer, { range }, 1)
end

return M
