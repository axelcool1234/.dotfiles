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

function M.new(buffer, ranges, primary_index)
  assert(#ranges > 0, "a selection must contain at least one range")
  local copied = {}
  local original_primary = ranges[primary_index or 1]
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
