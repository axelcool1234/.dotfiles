local M = {}
local position = require("axelcool1234.helix.position")
local range_module = require("axelcool1234.helix.range")

function M.new(opts)
  local insert_preview = {}

  local function range_from_cells(anchor, cursor, range_opts)
    return range_module.from_cells(vim.api.nvim_get_current_buf(), anchor, cursor, range_opts)
  end

  local function display_col(point)
    return position.display_col(vim.api.nvim_get_current_buf(), point)
  end

  local function anchored_entries(points, anchors)
    local entries = {}
    for index, point in ipairs(points) do
      if point then
        local anchor = anchors and anchors[index] or nil
        if anchor then
          entries[#entries + 1] = range_from_cells(anchor, point)
        else
          entries[#entries + 1] = range_from_cells(point, point)
        end
      end
    end

    return entries
  end

  local function bounded_entries(points, start_anchors, end_anchors)
    local entries = {}

    for index, point in ipairs(points) do
      local start_anchor = start_anchors[index]
      local end_anchor = end_anchors[index]
      if start_anchor and end_anchor then
        -- `i` inserts at the normalized start of the selection, so that edge
        -- becomes the active cursor when the insert session rebuilds it.
        entries[#entries + 1] = range_from_cells(end_anchor, start_anchor)
      elseif start_anchor then
        entries[#entries + 1] = range_from_cells(start_anchor, start_anchor)
      elseif end_anchor then
        entries[#entries + 1] = range_from_cells(end_anchor, end_anchor)
      else
        entries[#entries + 1] = range_from_cells(point, point)
      end
    end

    return entries
  end

  function insert_preview.build_live(points, anchors, end_anchors, selection_config)
    selection_config = selection_config or {}
    if selection_config.preview_ranges == "between_anchors" then
      return bounded_entries(points, anchors or {}, end_anchors or {})
    end

    return anchored_entries(points, anchors)
  end

  function insert_preview.build_snapshot(entries, selection_config)
    selection_config = selection_config or {}

    local preview_ranges = {}
    local count = math.max(#entries, #(selection_config.selection_anchors or {}), #(selection_config.selection_ends or {}))

    local function append(entry, cursor)
      if not vim.deep_equal(cursor, entry:cursor()) then
        entry.visual_cursor = vim.deepcopy(cursor)
      end
      entry.goal_display_col = display_col(cursor)
      preview_ranges[#preview_ranges + 1] = entry
    end

    for index = 1, count do
      local entry = entries[index]
      local point = entry and entry:cursor() or nil
      local anchor_spec = selection_config.selection_anchors and selection_config.selection_anchors[index] or nil
      local end_spec = selection_config.selection_ends and selection_config.selection_ends[index] or nil
      local anchor = anchor_spec and anchor_spec.pos or nil
      local ending = end_spec and end_spec.pos or nil

      if selection_config.preview_ranges == "between_anchors" then
        if anchor and ending then
          local cursor = point or ending
          local opposite = ending
          if cursor[1] == ending[1] and cursor[2] == ending[2] then
            opposite = anchor
          end
          append(range_from_cells(opposite, cursor), cursor)
        elseif anchor then
          append(range_from_cells(anchor, anchor), point or anchor)
        elseif ending then
          append(range_from_cells(ending, ending), point or ending)
        elseif point then
          append(range_from_cells(point, point), point)
        end
      elseif point then
        if anchor then
          append(range_from_cells(anchor, point), point)
        else
          append(range_from_cells(point, point), point)
        end
      end
    end

    return preview_ranges
  end

  return insert_preview
end

return M
