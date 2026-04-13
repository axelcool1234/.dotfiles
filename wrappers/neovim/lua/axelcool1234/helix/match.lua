local M = {}

function M.new(opts)
  local state = opts.state
  local state_module = opts.state_module
  local position = opts.position
  local history = opts.history
  local getcharstr = opts.getcharstr

  local match = {}
  local textobject_query_cache = {}
  local find_surround_region_for_entry
  local surround_region_entry_for_source
  local inner_surround_region

  local function current_buffer()
    return vim.api.nvim_get_current_buf()
  end

  local function line_text(row)
    return position.line_text(current_buffer(), row)
  end

  local function line_cursor_max_column(row)
    return position.cursor_max_column(current_buffer(), row)
  end

  local function current_entries()
    return state.current_entries()
  end

  local function current_preview_entries()
    if not state.preview_active() then
      return {}
    end

    return vim.deepcopy(state.preview.entries)
  end

  local function current_preview_history_config()
    if not state.preview_active() then
      return {}
    end

    return {
      cursor_positions = vim.deepcopy(state.preview.cursor_positions or {}),
      preferred_columns = vim.deepcopy(state.preview.preferred_columns or {}),
    }
  end

  local function set_preview_entries(entries, config)
    return state.set_preview_entries(current_buffer(), entries, config)
  end

  local function sync_cursors_to_points(points, config)
    if #points == 0 then
      return
    end

    local entries = {}
    for _, point in ipairs(points) do
      table.insert(entries, state_module.selection_entry(point, point))
    end
    state.set_preview_entries(current_buffer(), entries, config)
  end

  -- Pair helpers

  local function surround_pair(char)
    local pairs = {
      ["("] = { "(", ")" },
      [")"] = { "(", ")" },
      ["["] = { "[", "]" },
      ["]"] = { "[", "]" },
      ["{"] = { "{", "}" },
      ["}"] = { "{", "}" },
      ["<"] = { "<", ">" },
      [">"] = { "<", ">" },
      ['"'] = { '"', '"' },
      ["'"] = { "'", "'" },
      ["`"] = { "`", "`" },
    }

    return pairs[char] or { char, char }
  end

  local surround_pairs = {
    { "(", ")" },
    { "[", "]" },
    { "{", "}" },
    { "<", ">" },
    { '"', '"' },
    { "'", "'" },
    { "`", "`" },
  }

  local function pos_before(left, right)
    return left[1] < right[1] or (left[1] == right[1] and left[2] < right[2])
  end

  local function pos_after(left, right)
    return left[1] > right[1] or (left[1] == right[1] and left[2] > right[2])
  end

  local function pos_equal(left, right)
    return left[1] == right[1] and left[2] == right[2]
  end

  local function pos_leq(left, right)
    return pos_before(left, right) or pos_equal(left, right)
  end

  local function region_entry_positions(region)
    return region.start_pos, region.end_pos
  end

  local function region_contains_pos(region, pos)
    local start_pos, end_pos = region_entry_positions(region)
    return not pos_before(pos, start_pos) and not pos_after(pos, end_pos)
  end

  local function region_contains_entry(region, entry)
    local start_pos, end_pos = region_entry_positions(region)
    return not pos_before(entry.start_pos, start_pos) and not pos_after(entry.end_pos, end_pos)
  end

  local function entry_is_point(entry)
    return pos_equal(entry.start_pos, entry.end_pos)
  end

  local function region_strictly_contains_entry(region, entry)
    local start_pos, end_pos = region_entry_positions(region)
    return pos_before(start_pos, entry.start_pos) and pos_after(end_pos, entry.end_pos)
  end

  local function region_span(region)
    local start_pos, end_pos = region_entry_positions(region)
    local line_span = end_pos[1] - start_pos[1]
    if line_span == 0 then
      return end_pos[2] - start_pos[2]
    end

    return line_span * 1000000 + end_pos[2] - start_pos[2]
  end

  local function all_buffer_lines()
    return vim.api.nvim_buf_get_lines(current_buffer(), 0, -1, false)
  end

  local function current_lang()
    local ft = vim.bo[current_buffer()].filetype
    return vim.treesitter.language.get_lang(ft) or ft
  end

  local function load_textobject_query(lang)
    if textobject_query_cache[lang] ~= nil then
      return textobject_query_cache[lang]
    end

    local query = nil
    local style = nil
    local helix_path = vim.fn.expand("~/Projects/helix/runtime/queries/" .. lang .. "/textobjects.scm")
    if vim.fn.filereadable(helix_path) == 1 then
      local content = table.concat(vim.fn.readfile(helix_path), "\n")
      local ok, parsed = pcall(vim.treesitter.query.parse, lang, content)
      if ok then
        query = parsed
        style = "helix"
      end
    end

    if not query then
      local ok, parsed = pcall(vim.treesitter.query.get, lang, "textobjects")
      if ok then
        query = parsed
        style = "nvim"
      end
    end

    textobject_query_cache[lang] = { query = query, style = style }
    return textobject_query_cache[lang]
  end

  local function capture_names_for_object(object_name, around)
    local suffixes = around and { ".around", ".outer" } or { ".inside", ".inner" }
    local names = {}
    for _, suffix in ipairs(suffixes) do
      names[#names + 1] = object_name .. suffix
    end
    return names
  end

  local function capture_names_for_goto(object_name)
    return {
      object_name .. ".movement",
      object_name .. ".around",
      object_name .. ".outer",
      object_name .. ".inside",
      object_name .. ".inner",
    }
  end

  local function capture_region_for_entry(object_name, source_entry, around)
    local lang = current_lang()
    if not lang or lang == "" then
      return nil
    end

    local parser_ok = pcall(vim.treesitter.get_parser, current_buffer(), lang)
    if not parser_ok then
      return nil
    end

    local loaded = load_textobject_query(lang)
    local query = loaded and loaded.query or nil
    if not query then
      return nil
    end

    local root = vim.treesitter.get_parser(current_buffer(), lang):parse()[1]:root()
    local target_captures = {}
    for _, name in ipairs(capture_names_for_object(object_name, around)) do
      target_captures[name] = true
    end

    local best = nil
    for id, node in query:iter_captures(root, current_buffer(), 0, -1) do
      local capture = query.captures[id]
      if target_captures[capture] then
        local start_row, start_col, end_row, end_col = node:range()
        local start_pos = { start_row + 1, start_col + 1 }
        local end_boundary = { end_row + 1, end_col + 1 }
        local end_pos = pos_equal(start_pos, end_boundary) and start_pos or position.prev_pos(current_buffer(), end_boundary)
        if pos_leq(start_pos, source_entry.start_pos) and pos_leq(source_entry.end_pos, end_pos) then
          local candidate = {
            start_pos = start_pos,
            end_pos = end_pos,
          }
          if not best or region_span(candidate) < region_span(best) then
            best = candidate
          end
        end
      end
    end

    return best
  end

  local function goto_capture_region_for_entry(object_name, source_entry, direction, count)
    local lang = current_lang()
    if not lang or lang == "" then
      return source_entry
    end

    local ok, parser = pcall(vim.treesitter.get_parser, current_buffer(), lang)
    if not ok or not parser then
      return source_entry
    end

    local loaded = load_textobject_query(lang)
    local query = loaded and loaded.query or nil
    if not query then
      return source_entry
    end

    local root = parser:parse()[1]:root()
    local target_captures = {}
    for _, name in ipairs(capture_names_for_goto(object_name)) do
      target_captures[name] = true
    end

    local function region_for_cursor(cursor_pos)
      local best = nil
      for id, node in query:iter_captures(root, current_buffer(), 0, -1) do
        local capture = query.captures[id]
        if target_captures[capture] then
          local start_row, start_col, end_row, end_col = node:range()
          local start_pos = { start_row + 1, start_col + 1 }
          local end_boundary = { end_row + 1, end_col + 1 }
          local end_pos = pos_equal(start_pos, end_boundary) and start_pos or position.prev_pos(current_buffer(), end_boundary)
          local candidate = { start_pos = start_pos, end_pos = end_pos }

          if direction == "forward" then
            if pos_before(cursor_pos, start_pos) then
              if not best
                or pos_before(start_pos, best.start_pos)
                or (pos_equal(start_pos, best.start_pos) and pos_after(end_pos, best.end_pos)) then
                best = candidate
              end
            end
          else
            if pos_before(end_pos, cursor_pos) then
              if not best
                or pos_after(end_pos, best.end_pos)
                or (pos_equal(end_pos, best.end_pos) and pos_before(start_pos, best.start_pos)) then
                best = candidate
              end
            end
          end
        end
      end
      return best
    end

    local current = source_entry
    for _ = 1, count do
      local cursor_pos = current.cursor_pos
      local region = region_for_cursor(cursor_pos)
      if not region then
        break
      end
      if direction == "forward" then
        current = state_module.selection_entry(region.start_pos, region.end_pos)
      else
        current = state_module.selection_entry(region.end_pos, region.start_pos)
      end
    end

    return current
  end

  local function char_kind(ch, long)
    if ch == nil or ch == "" then
      return "space"
    end
    if ch:match("%s") then
      return "space"
    end
    if long then
      return "word"
    end
    if ch:match("[%w_]") then
      return "word"
    end
    return "punct"
  end

  local function textobject_word_entry(source_entry, around, long)
    local row = source_entry.cursor_pos[1]
    local line = line_text(row)
    if line == "" then
      return state_module.selection_entry(source_entry.cursor_pos, source_entry.cursor_pos)
    end

    local cursor_col = math.min(source_entry.cursor_pos[2], #line + 1)
    local anchor_col = cursor_col
    local kind = char_kind(line:sub(anchor_col, anchor_col), long)
    if kind == "space" then
      return state_module.selection_entry(source_entry.cursor_pos, source_entry.cursor_pos)
    end

    local start_col = anchor_col
    while start_col > 1 and char_kind(line:sub(start_col - 1, start_col - 1), long) == kind do
      start_col = start_col - 1
    end

    local end_col = anchor_col
    while end_col < #line and char_kind(line:sub(end_col + 1, end_col + 1), long) == kind do
      end_col = end_col + 1
    end

    if around then
      local right = end_col + 1
      local right_whitespace = 0
      while right <= #line and line:sub(right, right):match("%s") do
        end_col = right
        right = right + 1
        right_whitespace = right_whitespace + 1
      end
      if right_whitespace == 0 then
        local left = start_col - 1
        while left >= 1 and line:sub(left, left):match("%s") do
          start_col = left
          left = left - 1
        end
      end
    end
    local entry = state_module.selection_entry({ row, start_col }, { row, end_col })
    if pos_equal(entry.start_pos, entry.end_pos) then
      entry.force_highlight = true
    end
    return entry
  end

  local function line_is_blank(row)
    return line_text(row):match("^%s*$") ~= nil
  end

  local function line_is_empty(row)
    return line_text(row) == ""
  end

  local function indent_level_for_line_text(line)
    local tab_width = vim.bo[current_buffer()].tabstop
    local indent_width = vim.bo[current_buffer()].shiftwidth
    if indent_width == 0 then
      indent_width = vim.bo[current_buffer()].tabstop
    end

    local len = 0
    for i = 1, #line do
      local ch = line:sub(i, i)
      if ch == "\t" then
        local step = tab_width - (len % tab_width)
        len = len + step
      elseif ch == " " then
        len = len + 1
      else
        break
      end
    end

    return math.floor(len / math.max(indent_width, 1))
  end

  local function textobject_paragraph_entry(source_entry, around)
    local last_row = vim.api.nvim_buf_line_count(current_buffer())
    local row = source_entry.cursor_pos[1]
    local start_row = row
    local end_row = row

    if line_is_blank(row) then
      while start_row > 1 and line_is_blank(start_row - 1) do
        start_row = start_row - 1
      end
      while end_row < last_row and line_is_blank(end_row + 1) do
        end_row = end_row + 1
      end
      return state_module.selection_entry({ start_row, 1 }, { end_row, line_cursor_max_column(end_row) })
    end

    while start_row > 1 and not line_is_blank(start_row - 1) do
      start_row = start_row - 1
    end
    while end_row < last_row and not line_is_blank(end_row + 1) do
      end_row = end_row + 1
    end

    if around then
      while end_row < last_row and line_is_blank(end_row + 1) do
        end_row = end_row + 1
      end
    end

    return state_module.selection_entry({ start_row, 1 }, { end_row, line_cursor_max_column(end_row) })
  end

  local function textobject_indentation_entry(source_entry, around)
    local count = vim.v.count1
    local last_row = vim.api.nvim_buf_line_count(current_buffer())
    local line_start = source_entry.start_pos[1]
    local line_end = source_entry.end_pos[1]
    local min_indent = nil

    for row = line_start, line_end do
      local line = line_text(row)
      if line ~= "" then
        local indent = indent_level_for_line_text(line)
        min_indent = min_indent and math.min(min_indent, indent) or indent
      end
    end

    if min_indent == nil then
      return source_entry
    end

    min_indent = min_indent + 1 - count

    while line_start > 1 do
      local row = line_start - 1
      local line = line_text(row)
      local indent = indent_level_for_line_text(line)
      local empty = line_is_empty(row)
      if (min_indent > 0 and indent >= min_indent)
        or (min_indent == 0 and not empty)
        or (around and empty) then
        line_start = row
      else
        break
      end
    end

    while line_end < last_row do
      local row = line_end + 1
      local line = line_text(row)
      local indent = indent_level_for_line_text(line)
      local empty = line_is_empty(row)
      if (min_indent > 0 and indent >= min_indent)
        or (min_indent == 0 and not empty)
        or (around and empty) then
        line_end = row
      else
        break
      end
    end

    if not around then
      while line_end > line_start and line_is_empty(line_end) do
        line_end = line_end - 1
      end
    end

    local end_col = position.text_end_column(current_buffer(), line_end)
    return state_module.selection_entry({ line_start, 1 }, { line_end, end_col })
  end

  local function textobject_change_entry(source_entry)
    local cache = require("gitsigns.cache").cache[current_buffer()]
    if not cache then
      return source_entry
    end

    local hunks = cache:get_hunks(false, false)
    if not hunks then
      return source_entry
    end

    local row = source_entry.cursor_pos[1]
    local hunk = require("gitsigns.hunks").find_hunk(row, hunks)
    if not hunk or not hunk.added then
      return source_entry
    end

    local start_row = math.max(hunk.added.start, 1)
    local end_row = math.max(hunk.vend, start_row)
    end_row = math.min(end_row, vim.api.nvim_buf_line_count(current_buffer()))
    return state_module.selection_entry({ start_row, 1 }, { end_row, line_cursor_max_column(end_row) })
  end

  local function textobject_entry(source_entry, char, around)
    if char == "w" then
      return textobject_word_entry(source_entry, around, false)
    end
    if char == "W" then
      return textobject_word_entry(source_entry, around, true)
    end
    if char == "p" then
      return textobject_paragraph_entry(source_entry, around)
    end
    if char == "i" then
      return textobject_indentation_entry(source_entry, around)
    end
    if char == "g" then
      return textobject_change_entry(source_entry)
    end

    local ts_objects = {
      t = "class",
      f = "function",
      a = "parameter",
      c = "comment",
      e = "entry",
      x = "xml-element",
    }
    local object_name = ts_objects[char]
    if object_name then
      local region = capture_region_for_entry(object_name, source_entry, around)
      if region then
        local entry = state_module.selection_entry(region.start_pos, region.end_pos)
        if pos_equal(entry.start_pos, entry.end_pos) then
          entry.force_highlight = true
        end
        return entry
      end
      return source_entry
    end

    if char == "m" then
      local region = find_surround_region_for_entry(source_entry, nil)
      region = around and region or inner_surround_region(region)
      local entry = surround_region_entry_for_source(region, source_entry)
      if entry and pos_equal(entry.start_pos, entry.end_pos) then
        entry.force_highlight = true
      end
      return entry or source_entry
    end

    if not char:match("[%w_]") then
      local region = find_surround_region_for_entry(source_entry, char)
      region = around and region or inner_surround_region(region)
      local entry = surround_region_entry_for_source(region, source_entry)
      if entry and pos_equal(entry.start_pos, entry.end_pos) then
        entry.force_highlight = true
      end
      return entry or source_entry
    end

    return source_entry
  end

  function match.select_textobject_at_point(point, char, around)
    local source_entry = state_module.selection_entry(point, point)
    return textobject_entry(source_entry, char, around)
  end

  local function select_textobject_preview(around)
    local char = getcharstr()
    if not char then
      return
    end

    local buffer = current_buffer()
    local source_entries = state.preview_active() and current_preview_entries() or current_entries()
    local entries = {}
    for _, source_entry in ipairs(source_entries) do
      entries[#entries + 1] = textobject_entry(source_entry, char, around)
    end

    state.set_preview_entries(buffer, entries)
  end

  function match.goto_textobject(object_name, direction)
    local buffer = current_buffer()
    local source_entries = state.preview_active() and current_preview_entries() or current_entries()
    local count = vim.v.count1
    local entries = {}

    for _, source_entry in ipairs(source_entries) do
      entries[#entries + 1] = goto_capture_region_for_entry(object_name, source_entry, direction, count)
    end

    state.set_preview_entries(buffer, entries)
    if not state.extend_mode_active() then
      state.exit_extend_mode()
    end
  end

  local function all_char_positions_for(char)
    local positions = {}
    for row, line in ipairs(all_buffer_lines()) do
      for col = 1, #line do
        if line:sub(col, col) == char then
          positions[#positions + 1] = { row, col }
        end
      end
    end

    return positions
  end

  local function narrower_region(left, right)
    if not left then
      return right
    end

    if not right then
      return left
    end

    if region_span(left) <= region_span(right) then
      return left
    end

    return right
  end

  local function single_char_text(node)
    if not node then
      return nil
    end

    local text = vim.treesitter.get_node_text(node, 0)
    if not text or vim.fn.strchars(text) ~= 1 then
      return nil
    end

    return text
  end

  local function pair_region_from_ts_node(node, char)
    if not node or node:child_count() < 2 then
      return nil
    end

    local open_node = node:child(0)
    local close_node = node:child(node:child_count() - 1)
    local open_char = single_char_text(open_node)
    local close_char = single_char_text(close_node)
    if not open_char or not close_char then
      return nil
    end

    local valid = false
    for _, candidate in ipairs(surround_pairs) do
      if candidate[1] == open_char and candidate[2] == close_char then
        valid = true
        break
      end
    end

    if not valid then
      return nil
    end

    local pair = char and surround_pair(char) or nil
    if pair and (pair[1] ~= open_char or pair[2] ~= close_char) then
      return nil
    end

    local start_row, start_col, _, _ = open_node:start()
    local end_row, end_col, _, _ = close_node:end_()
    return {
      start_pos = { start_row + 1, start_col + 1 },
      end_pos = { end_row + 1, end_col },
      open_char = open_char,
      close_char = close_char,
    }
  end

  local function pair_for_char(ch)
    for _, candidate in ipairs(surround_pairs) do
      if candidate[1] == ch or candidate[2] == ch then
        return candidate
      end
    end

    return nil
  end

  local function region_from_ts_nodes(open_node, close_node)
    local open_char = single_char_text(open_node)
    local close_char = single_char_text(close_node)
    if not open_char or not close_char then
      return nil
    end

    local pair = pair_for_char(open_char)
    if not pair or pair[1] ~= open_char or pair[2] ~= close_char then
      return nil
    end

    local start_row, start_col, _, _ = open_node:start()
    local end_row, end_col, _, _ = close_node:end_()
    return {
      start_pos = { start_row + 1, start_col + 1 },
      end_pos = { end_row + 1, end_col },
      open_char = open_char,
      close_char = close_char,
    }
  end

  local function sibling_pair_region(node, char)
    local node_char = single_char_text(node)
    local pair = node_char and pair_for_char(node_char) or nil
    if not pair or pair[1] == pair[2] then
      return nil
    end

    if char then
      local explicit = surround_pair(char)
      if explicit[1] ~= pair[1] or explicit[2] ~= pair[2] then
        return nil
      end
    end

    local limit = 16
    if node_char == pair[2] then
      local depth = 0
      local sibling = node:prev_sibling()
      while sibling and limit > 0 do
        limit = limit - 1
        local sibling_char = single_char_text(sibling)
        if sibling_char == pair[2] then
          depth = depth + 1
        elseif sibling_char == pair[1] then
          if depth == 0 then
            return region_from_ts_nodes(sibling, node)
          end
          depth = depth - 1
        end
        sibling = sibling:prev_sibling()
      end
    elseif node_char == pair[1] then
      local depth = 0
      local sibling = node:next_sibling()
      while sibling and limit > 0 do
        limit = limit - 1
        local sibling_char = single_char_text(sibling)
        if sibling_char == pair[1] then
          depth = depth + 1
        elseif sibling_char == pair[2] then
          if depth == 0 then
            return region_from_ts_nodes(node, sibling)
          end
          depth = depth - 1
        end
        sibling = sibling:next_sibling()
      end
    end

    return nil
  end

  -- Tree-sitter-backed pair discovery

  local function find_surround_with_treesitter(ref, char, count)
    local buffer = vim.api.nvim_get_current_buf()
    local parser = vim.treesitter.get_parser(buffer)
    local tree = parser:parse()[1]
    if not tree then
      return nil
    end

    local line = line_text(ref[1])
    if line == "" then
      return nil
    end

    local col0 = math.max(math.min(ref[2] - 1, math.max(#line - 1, 0)), 0)
    local node = tree:root():descendant_for_range(ref[1] - 1, col0, ref[1] - 1, math.min(col0 + 1, #line))
    local seen = {}

    while node do
      local region = pair_region_from_ts_node(node, char) or sibling_pair_region(node, char)
      if region and region_contains_pos(region, ref) then
        local key = string.format(
          "%d:%d:%d:%d",
          region.start_pos[1],
          region.start_pos[2],
          region.end_pos[1],
          region.end_pos[2]
        )
        if not seen[key] then
          seen[key] = true
          count = count - 1
          if count == 0 then
            return region
          end
        end
      end

      node = node:parent()
    end

    return nil
  end

  local function find_surround_with_treesitter_for_entry(entry, char, count)
    local buffer = vim.api.nvim_get_current_buf()
    local parser = vim.treesitter.get_parser(buffer)
    local tree = parser:parse()[1]
    if not tree then
      return nil
    end

    local start_row = entry.start_pos[1] - 1
    local start_col = math.max(entry.start_pos[2] - 1, 0)
    local end_row = entry.end_pos[1] - 1
    local end_col = math.max(entry.end_pos[2] - 1, 0)
    local node = tree:root():descendant_for_range(start_row, start_col, end_row, end_col)
    local seen = {}

    while node do
      local region = pair_region_from_ts_node(node, char) or sibling_pair_region(node, char)
      local contains = region and (
        (entry_is_point(entry) and region_contains_entry(region, entry))
        or (not entry_is_point(entry) and region_strictly_contains_entry(region, entry))
      )
      if contains then
        local key = string.format(
          "%d:%d:%d:%d",
          region.start_pos[1],
          region.start_pos[2],
          region.end_pos[1],
          region.end_pos[2]
        )
        if not seen[key] then
          seen[key] = true
          count = count - 1
          if count == 0 then
            return region
          end
        end
      end

      node = node:parent()
    end

    return nil
  end

  -- Plain-text fallback pair discovery

  local function find_surrounds(char)
    local pair = char and surround_pair(char) or nil
    local candidates = pair and { pair } or surround_pairs
    local regions = {}

    local function consider_candidate(left_pos, right_pos, left, right)
      if left_pos and right_pos and pos_before(left_pos, right_pos) then
        regions[#regions + 1] = {
          start_pos = left_pos,
          end_pos = right_pos,
          open_char = left,
          close_char = right,
          width = region_span({ start_pos = left_pos, end_pos = right_pos }),
        }
      end
    end

    for _, candidate in ipairs(candidates) do
      local left, right = candidate[1], candidate[2]

      if left == right then
        local positions = all_char_positions_for(left)

        for index = 1, #positions - 1, 2 do
          consider_candidate(positions[index], positions[index + 1], left, right)
        end

        goto continue_candidates
      end

      local stack = {}
      for row, line in ipairs(all_buffer_lines()) do
        for col = 1, #line do
          local current = line:sub(col, col)
          if current == left then
            stack[#stack + 1] = { row, col }
          elseif current == right and #stack > 0 then
            consider_candidate(stack[#stack], { row, col }, left, right)
            stack[#stack] = nil
          end
        end
      end

      ::continue_candidates::
    end

    table.sort(regions, function(a, b)
      if a.width == b.width then
        if a.start_pos[1] == b.start_pos[1] then
          return a.start_pos[2] < b.start_pos[2]
        end

        return a.start_pos[1] < b.start_pos[1]
      end

      return a.width < b.width
    end)

    return regions
  end

  local function find_explicit_same_char(char, ref_pos, count, left_bound, right_bound)
    local positions = all_char_positions_for(char)

    local left_pos = nil
    local seen = 0
    for index = #positions, 1, -1 do
      if pos_before(positions[index], left_bound or ref_pos) then
        seen = seen + 1
        if seen == count then
          left_pos = positions[index]
          break
        end
      end
    end

    local right_pos = nil
    seen = 0
    for index = 1, #positions do
      if pos_after(positions[index], right_bound or ref_pos) then
        seen = seen + 1
        if seen == count then
          right_pos = positions[index]
          break
        end
      end
    end

    if left_pos and right_pos and pos_before(left_pos, right_pos) then
      return {
        start_pos = left_pos,
        end_pos = right_pos,
        open_char = char,
        close_char = char,
        width = region_span({ start_pos = left_pos, end_pos = right_pos }),
      }
    end

    return nil
  end

  local function find_surround_on_buffer(ref_pos, char)
    for _, region in ipairs(find_surrounds(char)) do
      if region_contains_pos(region, ref_pos) then
        return region
      end
    end

    return nil
  end

  local function find_surround_region(ref, char)
    local count = vim.v.count1
    local explicit_pair = char and surround_pair(char) or nil
    if explicit_pair and explicit_pair[1] == explicit_pair[2] then
      return find_explicit_same_char(char, ref, count)
    end

    local ts_region = nil
    local ok, region = pcall(find_surround_with_treesitter, ref, char, count)
    if ok then
      ts_region = region
    end

    if count > 1 then
      local plain_regions = {}
      for _, region in ipairs(find_surrounds(char)) do
        if region_contains_pos(region, ref) then
          plain_regions[#plain_regions + 1] = region
        end
      end

      return narrower_region(ts_region, plain_regions[count])
    end

    local plain_region = find_surround_on_buffer(ref, char)
    if not plain_region and ts_region and ts_region.open_char == ts_region.close_char then
      return nil
    end

    return narrower_region(ts_region, plain_region)
  end

  find_surround_region_for_entry = function(entry, char)
    local count = vim.v.count1
    local explicit_pair = char and surround_pair(char) or nil
    if explicit_pair and explicit_pair[1] == explicit_pair[2] then
      return find_explicit_same_char(
        char,
        entry.cursor_pos,
        count,
        entry_is_point(entry) and entry.cursor_pos or entry.start_pos,
        entry_is_point(entry) and entry.cursor_pos or entry.end_pos
      )
    end

    local ts_region = nil
    local ok, region = pcall(find_surround_with_treesitter_for_entry, entry, char, count)
    if ok then
      ts_region = region
    end

    local point_col = entry.cursor_pos[2]
    local plain_regions = {}
    for _, region in ipairs(find_surrounds(char)) do
      local contains = entry_is_point(entry) and region_contains_entry(region, entry)
        or region_strictly_contains_entry(region, entry)
      if contains then
        plain_regions[#plain_regions + 1] = region
      end
    end

    if count > 1 then
      return narrower_region(ts_region, plain_regions[count])
    end

    local plain_region = nil
    for _, region in ipairs(plain_regions) do
      if region_contains_pos(region, entry.cursor_pos) then
        plain_region = region
        break
      end
    end

    plain_region = plain_region or plain_regions[1]
    if not plain_region and ts_region and ts_region.open_char == ts_region.close_char then
      return nil
    end

    return narrower_region(ts_region, plain_region)
  end

  -- Buffer edit helpers

  local function delete_surround_region(region)
    if not region then
      return false
    end

    local start_pos, end_pos = region_entry_positions(region)
    vim.api.nvim_buf_set_text(0, end_pos[1] - 1, end_pos[2] - 1, end_pos[1] - 1, end_pos[2], { "" })
    vim.api.nvim_buf_set_text(0, start_pos[1] - 1, start_pos[2] - 1, start_pos[1] - 1, start_pos[2], { "" })
    return true
  end

  local function replace_surround_region(region, char)
    if not region then
      return false
    end

    local pair = surround_pair(char)
    local start_pos, end_pos = region_entry_positions(region)
    vim.api.nvim_buf_set_text(0, end_pos[1] - 1, end_pos[2] - 1, end_pos[1] - 1, end_pos[2], { pair[2] })
    vim.api.nvim_buf_set_text(0, start_pos[1] - 1, start_pos[2] - 1, start_pos[1] - 1, start_pos[2], { pair[1] })
    return true
  end

  local function region_key(region)
    return string.format(
      "%d:%d:%d:%d",
      region.start_pos[1],
      region.start_pos[2],
      region.end_pos[1],
      region.end_pos[2]
    )
  end

  local function sort_regions_desc(left, right)
    if left.end_pos[1] == right.end_pos[1] then
      if left.end_pos[2] == right.end_pos[2] then
        if left.start_pos[1] == right.start_pos[1] then
          return left.start_pos[2] > right.start_pos[2]
        end

        return left.start_pos[1] > right.start_pos[1]
      end

      return left.end_pos[2] > right.end_pos[2]
    end

    return left.end_pos[1] > right.end_pos[1]
  end

  local function echo_match_error(message)
    vim.api.nvim_echo({ { message, "ErrorMsg" } }, false, {})
  end

  local function collect_surround_regions(entries, char)
    local regions = {}
    local seen = {}

    for _, entry in ipairs(entries) do
      local first = find_surround_region(entry.start_pos, char)
      if not first then
        return nil, "Surround pair not found around all cursors"
      end

      local first_key = region_key(first)
      if seen[first_key] then
        return nil, "Cursors overlap for a single surround pair range"
      end
      seen[first_key] = true
      regions[#regions + 1] = first

      if entry.start_pos[1] ~= entry.end_pos[1] then
        local last = find_surround_region(entry.end_pos, char)
        if not last then
          return nil, "Surround pair not found around all cursors"
        end

        local last_key = region_key(last)
        if last_key ~= first_key then
          if seen[last_key] then
            return nil, "Cursors overlap for a single surround pair range"
          end
          seen[last_key] = true
          regions[#regions + 1] = last
        end
      end
    end

    table.sort(regions, sort_regions_desc)
    return regions, nil
  end

  local function delete_surround_regions(regions)
    for _, region in ipairs(regions) do
      delete_surround_region(region)
    end
  end

  local function current_cursor_target()
    local row, col0 = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
    if line ~= "" then
      col0 = math.min(col0, #line - 1)
    end

    return {
      start_row = row,
      start_col0 = col0,
      end_row = row,
      end_col0 = line == "" and col0 or col0 + 1,
    }
  end

  local function sort_edit_desc(left, right)
    if left.row == right.row then
      return left.col0 > right.col0
    end

    return left.row > right.row
  end

  local function surround_targets(targets, pair)
    if #targets == 0 then
      return {}
    end

    local buffer = vim.api.nvim_get_current_buf()
    local namespace = vim.api.nvim_create_namespace("axelcool1234-surround-targets")
    local edits = {}

    for _, target in ipairs(targets) do
      target.start_mark = vim.api.nvim_buf_set_extmark(buffer, namespace, target.start_row - 1, target.start_col0, {
        right_gravity = false,
      })
      target.end_mark = vim.api.nvim_buf_set_extmark(buffer, namespace, target.end_row - 1, target.end_col0, {
        right_gravity = true,
      })
      table.insert(edits, { row = target.end_row, col0 = target.end_col0, text = pair[2] })
      table.insert(edits, { row = target.start_row, col0 = target.start_col0, text = pair[1] })
    end

    table.sort(edits, sort_edit_desc)
    for _, edit in ipairs(edits) do
      vim.api.nvim_buf_set_text(buffer, edit.row - 1, edit.col0, edit.row - 1, edit.col0, { edit.text })
    end

    local bounds = {}
    for _, target in ipairs(targets) do
      local start_mark = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, target.start_mark, {})
      local end_mark = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace, target.end_mark, {})
      table.insert(bounds, {
        cursor = target.cursor,
        start_pos = { start_mark[1] + 1, start_mark[2] + 1 },
        end_pos = { end_mark[1] + 1, end_mark[2] },
      })
    end

    vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
    return bounds
  end

  local function surround_history_entries()
    if state.preview_active() then
      return current_preview_entries(), current_preview_history_config()
    end

    local entries = current_entries()
    return entries, {}
  end

  local function ambiguous_surround_char(entries, char)
    if not char then
      return false
    end

    local pair = surround_pair(char)
    if pair[1] ~= pair[2] then
      return false
    end

    for _, entry in ipairs(entries) do
      local row, col = entry.cursor_pos[1], entry.cursor_pos[2]
      local line = line_text(row)
      if line:sub(col, col) == char then
        return true
      end
    end

    return false
  end

  local function validate_explicit_surround_char(entries, char)
    if ambiguous_surround_char(entries, char) then
      return nil, "Cursor on ambiguous surround pair"
    end

    return true, nil
  end

  -- Public commands

  function match.surround_add()
    local addition = getcharstr()
    if not addition then
      return
    end

    local pair = surround_pair(addition)
    local history_entries, history_config = surround_history_entries()
    local transaction = history.transaction(history_entries, history_config)

    if state.preview_active() then
      local targets = {}
      for _, entry in ipairs(state.preview.entries) do
        table.insert(targets, {
          start_row = entry.start_pos[1],
          start_col0 = entry.start_pos[2] - 1,
          end_row = entry.end_pos[1],
          end_col0 = entry.end_pos[2],
        })
      end

      local bounds = surround_targets(targets, pair)
      local entries = {}
      for _, bound in ipairs(bounds) do
        table.insert(entries, state_module.selection_entry(bound.start_pos, bound.end_pos))
      end

      state.enter_extend_mode()
      state.set_preview_entries(vim.api.nvim_get_current_buf(), entries, { sync_history = false })
      transaction.commit_now()
      return
    end

    local source_entries = current_entries()
    if #source_entries > 1 then
      local targets = {}
      for _, entry in ipairs(source_entries) do
        table.insert(targets, {
          row = entry.cursor_pos[1],
          left = entry.cursor_pos[2],
          right = entry.cursor_pos[2],
        })
      end

      local bounds = surround_targets(targets, pair)
      local entries = {}
      for _, bound in ipairs(bounds) do
        table.insert(entries, state_module.selection_entry(bound.start_pos, bound.end_pos))
      end

      state.enter_extend_mode()
      state.set_preview_entries(vim.api.nvim_get_current_buf(), entries, { sync_history = false })
      transaction.commit_now()
      return
    end

    local bound = surround_targets({ current_cursor_target() }, pair)[1]
    state.enter_extend_mode()
    state.set_preview_entries(vim.api.nvim_get_current_buf(), {
      state_module.selection_entry(bound.start_pos, bound.end_pos),
    }, { sync_history = false })
    transaction.commit_now()
  end

  local function delete_surround_for_entries(entries, char)
    for index = #entries, 1, -1 do
      local entry = entries[index]
      delete_surround_region(find_surround_region(entry.start_pos, char))
      if entry.start_pos[1] ~= entry.end_pos[1] then
        delete_surround_region(find_surround_region(entry.end_pos, char))
      end
    end
  end

  function match.surround_delete()
    if state.preview_active() then
      local deletion = getcharstr()
      if not deletion then
        return
      end

      if deletion == "m" then
        deletion = nil
      end

      local entries = current_preview_entries()
      local valid, err = validate_explicit_surround_char(entries, deletion)
      if not valid then
        echo_match_error(err)
        return
      end

      local regions, err = collect_surround_regions(entries, deletion)
      if not regions then
        echo_match_error(err)
        return
      end

      local transaction = history.transaction(entries, current_preview_history_config())
      state.clear_preview()
      delete_surround_regions(regions)
      transaction.commit_now()
      return
    end

    local char = getcharstr()
    if not char then
      return
    end

    if char == "m" then
      char = nil
    end

    local entries, config = surround_history_entries()
    local valid, err = validate_explicit_surround_char(entries, char)
    if not valid then
      echo_match_error(err)
      return
    end

    local regions, err = collect_surround_regions(entries, char)
    if not regions then
      echo_match_error(err)
      return
    end

    local transaction = history.transaction(entries, config)
    delete_surround_regions(regions)
    transaction.commit_now()
  end

  function match.surround_replace()
    if state.preview_active() then
      local deletion = getcharstr()
      if not deletion then
        return
      end

      if deletion == "m" then
        deletion = nil
      end

      local entries = current_preview_entries()
      local valid, err = validate_explicit_surround_char(entries, deletion)
      if not valid then
        echo_match_error(err)
        return
      end

      local regions, err = collect_surround_regions(entries, deletion)
      if not regions then
        echo_match_error(err)
        return
      end

      local addition = getcharstr()
      if not addition then
        return
      end

      local transaction = history.transaction(entries, current_preview_history_config())
      state.clear_preview()
      for _, region in ipairs(regions) do
        replace_surround_region(region, addition)
      end
      transaction.commit_now()
      return
    end

    local deletion = getcharstr()
    if not deletion then
      return
    end

    if deletion == "m" then
      deletion = nil
    end

    local entries, config = surround_history_entries()
    local valid, err = validate_explicit_surround_char(entries, deletion)
    if not valid then
      echo_match_error(err)
      return
    end

    local regions, err = collect_surround_regions(entries, deletion)
    if not regions then
      echo_match_error(err)
      return
    end

    local addition = getcharstr()
    if not addition then
      return
    end

    local transaction = history.transaction(entries, config)
    for _, region in ipairs(regions) do
      replace_surround_region(region, addition)
    end
    transaction.commit_now()
  end

  function match.surround_delete_nearest()
    if state.preview_active() then
      local entries = current_preview_entries()
      local regions, err = collect_surround_regions(entries, nil)
      if not regions then
        echo_match_error(err)
        return
      end

      local transaction = history.transaction(entries, current_preview_history_config())
      state.clear_preview()
      delete_surround_regions(regions)
      transaction.commit_now()
      return
    end

    local entries, config = surround_history_entries()
    local regions, err = collect_surround_regions(entries, nil)
    if not regions then
      echo_match_error(err)
      return
    end

    local transaction = history.transaction(entries, config)
    delete_surround_regions(regions)
    transaction.commit_now()
  end

  -- Selection transforms

  local function surround_region_entry(region)
    if not region then
      return nil
    end

    return state_module.selection_entry(region.start_pos, region.end_pos)
  end

  surround_region_entry_for_source = function(region, source_entry)
    if not region then
      return nil
    end

    local start_pos, end_pos = region_entry_positions(region)
    if pos_before(source_entry.cursor_pos, source_entry.anchor_pos) then
      return state_module.selection_entry(end_pos, start_pos)
    end

    return state_module.selection_entry(start_pos, end_pos)
  end

  inner_surround_region = function(region)
    if not region then
      return nil
    end

    local start_pos, end_pos = region_entry_positions(region)

    if pos_equal(start_pos, end_pos) then
      return region
    end

    return {
      start_pos = position.next_pos(current_buffer(), start_pos),
      end_pos = position.prev_pos(current_buffer(), end_pos),
      open_char = region.open_char,
      close_char = region.close_char,
    }
  end

  local function select_surround_preview(transform_region)
    local char = getcharstr()
    if not char then
      return
    end

    if char == "m" then
      char = nil
    end

    local buffer = vim.api.nvim_get_current_buf()
    local source_entries = state.preview_active() and current_preview_entries() or current_entries()
    local valid, err = validate_explicit_surround_char(source_entries, char)
    if not valid then
      echo_match_error(err)
      return
    end

    local entries = {}
    for _, source_entry in ipairs(source_entries) do
      local region = transform_region(find_surround_region_for_entry(source_entry, char))
      local entry = surround_region_entry_for_source(region, source_entry)
      if not entry then
        return
      end

      table.insert(entries, entry)
    end

    state.set_preview_entries(buffer, entries)
  end

  function match.select_around_pair()
    select_textobject_preview(true)
  end

  function match.select_inside_pair()
    select_textobject_preview(false)
  end

  local function matching_pair_target(ref)
    local region = find_surround_region(ref, nil)
    if region then
      local start_pos, end_pos = region_entry_positions(region)
      if pos_equal(ref, end_pos) then
        return start_pos
      end

      return end_pos
    end

    return ref
  end

  function match.goto_match()
    if state.preview_active() and state.extend_mode_active() then
      local entries = current_preview_entries()
      local updated = {}

      for _, entry in ipairs(entries) do
        table.insert(updated, state_module.selection_entry(entry.anchor_pos, matching_pair_target(entry.cursor_pos)))
      end

      set_preview_entries(updated)
      return
    end

    local points = {}
    for _, entry in ipairs(current_entries()) do
      table.insert(points, matching_pair_target(entry.cursor_pos))
    end

    if state.preview_active() then
      state.clear_preview()
    end
    sync_cursors_to_points(points)
  end

  return match
end

return M
