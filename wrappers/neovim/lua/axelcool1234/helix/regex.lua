local position = require("axelcool1234.helix.position")
local range_module = require("axelcool1234.helix.range")

local M = {}

-- Vim's string matcher treats embedded newlines as ordinary characters. Give
-- the very-magic patterns used by the Helix commands buffer-style anchors and
-- dots, without rewriting escaped literals or characters inside a class.
local function multiline_pattern(pattern)
  local parts, in_class, class_start = {}, false, false
  local magic = "v"
  local index = 1
  while index <= #pattern do
    local char = pattern:sub(index, index)
    local next_char = pattern:sub(index + 1, index + 1)
    if char == "\\" then
      parts[#parts + 1] = pattern:sub(index, index + 1)
      if not in_class and next_char:match("^[vVmM]$") then magic = next_char end
      index = index + 2
    elseif in_class then
      -- POSIX character classes contain their own closing bracket.
      if char == "[" and (next_char == ":" or next_char == "." or next_char == "=") then
        local finish = pattern:find(next_char .. "]", index + 2, true)
        if finish then
          parts[#parts + 1] = pattern:sub(index, finish + 1)
          index = finish + 2
        else
          parts[#parts + 1] = char
          index = index + 1
        end
      else
        parts[#parts + 1] = char
        if char == "]" and not class_start then in_class = false end
        if char ~= "^" or not class_start then class_start = false end
        index = index + 1
      end
    else
      if magic == "v" and char == "[" then
        in_class, class_start = true, true
      end
      local replacement = magic == "v" and ({
        ["^"] = "%(^|\\n)@<=",
        ["$"] = "%($|\\n)@=",
        ["."] = "[^\\n]",
      })[char] or nil
      parts[#parts + 1] = replacement or char
      index = index + 1
    end
  end
  return table.concat(parts)
end

function M.matches(buffer, entry, compiled)
  local from, to = entry:from(), entry:to()
  -- Keep complete edge lines so anchors and word boundaries see their actual
  -- context. The ending column assertion bounds consuming matches, allowing
  -- greedy patterns to backtrack at the selection's exclusive end.
  local lines = vim.api.nvim_buf_get_lines(buffer, from.row - 1, to.row, false)
  local offsets, offset = {}, 0
  for index, line in ipairs(lines) do
    offsets[index] = offset
    offset = offset + #line + 1
  end
  local text = table.concat(lines, "\n")
  local first_byte = position.byte_col0_from_grapheme_col(lines[1], from.col + 1)
  local last_byte = offsets[#lines] + position.byte_col0_from_grapheme_col(lines[#lines], to.col + 1)
  local pattern = "\\v%(" .. multiline_pattern(compiled) .. "\\v)%<" .. (last_byte + 2) .. "c"

  local function byte_position(byte)
    local low, high = 1, #lines
    while low < high do
      local middle = math.floor((low + high + 1) / 2)
      if offsets[middle] <= byte then low = middle else high = middle - 1 end
    end
    return from.row + low - 2, byte - offsets[low]
  end

  local matches, cursor, previous_end = {}, first_byte, nil
  while cursor <= last_byte do
    -- The explicit count preserves ^ and word-boundary context when start > 0.
    local match = vim.fn.matchstrpos(text, pattern, cursor, 1)
    local start_byte, end_byte = match[2], match[3]
    if start_byte < 0 or start_byte > last_byte then break end
    -- Like Helix's regex iterator, suppress an empty match immediately after
    -- a consuming match at the same boundary.
    if end_byte > start_byte or start_byte ~= previous_end then
      local start_row, start_col = byte_position(start_byte)
      local end_row, end_col = byte_position(end_byte)
      matches[#matches + 1] = range_module.from_byte_range(buffer, start_row, start_col, end_row, end_col)
      previous_end = end_byte
    end
    if end_byte > start_byte then
      cursor = end_byte
    else
      -- Advance by a whole grapheme, never into the middle of UTF-8 text.
      local col = position.grapheme_col_from_byte_col0(text, start_byte)
      cursor = position.byte_col0_from_grapheme_col(text, col + 1)
      if cursor <= start_byte then break end
    end
  end
  return matches
end

return M
