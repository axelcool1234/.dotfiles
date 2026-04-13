local M = {}

function M.new(opts)
  local state_module = opts.state_module

  local insert_preview = {}

  local function anchored_entries(points, anchors)
    local entries = {}
    for index, point in ipairs(points) do
      if point then
        local anchor = anchors and anchors[index] or nil
        if anchor then
          entries[#entries + 1] = state_module.selection_entry(anchor, point)
        else
          entries[#entries + 1] = state_module.selection_entry(point, point)
        end
      end
    end

    return entries
  end

  local function bounded_entries(start_anchors, end_anchors)
    local entries = {}
    local count = math.max(#start_anchors, #end_anchors)

    for index = 1, count do
      local start_anchor = start_anchors[index]
      local end_anchor = end_anchors[index]
      if start_anchor and end_anchor then
        entries[#entries + 1] = state_module.selection_entry(start_anchor, end_anchor)
      elseif start_anchor then
        entries[#entries + 1] = state_module.selection_entry(start_anchor, start_anchor)
      elseif end_anchor then
        entries[#entries + 1] = state_module.selection_entry(end_anchor, end_anchor)
      end
    end

    return entries
  end

  function insert_preview.build_live(points, anchors, end_anchors, selection_config)
    selection_config = selection_config or {}
    if selection_config.preview_entries == "between_anchors" then
      return bounded_entries(anchors or {}, end_anchors or {})
    end

    return anchored_entries(points, anchors)
  end

  function insert_preview.build_snapshot(entries, selection_config)
    selection_config = selection_config or {}

    local preview_entries = {}
    local cursor_positions = {}
    local preferred_columns = {}
    local count = math.max(#entries, #(selection_config.selection_anchors or {}), #(selection_config.selection_ends or {}))

    for index = 1, count do
      local entry = entries[index]
      local point = entry and entry.cursor_pos or nil
      local anchor_spec = selection_config.selection_anchors and selection_config.selection_anchors[index] or nil
      local end_spec = selection_config.selection_ends and selection_config.selection_ends[index] or nil
      local anchor = anchor_spec and anchor_spec.pos or nil
      local ending = end_spec and end_spec.pos or nil

      if selection_config.preview_entries == "between_anchors" then
        if anchor and ending then
          local cursor = point or ending
          local opposite = ending
          if cursor[1] == ending[1] and cursor[2] == ending[2] then
            opposite = anchor
          end
          preview_entries[#preview_entries + 1] = state_module.selection_entry(opposite, cursor)
          cursor_positions[#cursor_positions + 1] = cursor
          preferred_columns[#preferred_columns + 1] = cursor[2]
        elseif anchor then
          preview_entries[#preview_entries + 1] = state_module.selection_entry(anchor, anchor)
          cursor_positions[#cursor_positions + 1] = point or anchor
          preferred_columns[#preferred_columns + 1] = (point or anchor)[2]
        elseif ending then
          preview_entries[#preview_entries + 1] = state_module.selection_entry(ending, ending)
          cursor_positions[#cursor_positions + 1] = point or ending
          preferred_columns[#preferred_columns + 1] = (point or ending)[2]
        elseif point then
          preview_entries[#preview_entries + 1] = state_module.selection_entry(point, point)
          cursor_positions[#cursor_positions + 1] = point
          preferred_columns[#preferred_columns + 1] = point[2]
        end
      elseif point then
        if anchor then
          preview_entries[#preview_entries + 1] = state_module.selection_entry(anchor, point)
        else
          preview_entries[#preview_entries + 1] = state_module.selection_entry(point, point)
        end
        cursor_positions[#cursor_positions + 1] = point
        preferred_columns[#preferred_columns + 1] = point[2]
      end
    end

    return preview_entries, {
      cursor_positions = cursor_positions,
      preferred_columns = preferred_columns,
    }
  end

  return insert_preview
end

return M
