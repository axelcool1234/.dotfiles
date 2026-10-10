local M = {}

local function reverse_concat(parts)
  local out = {}
  for index = #parts, 1, -1 do
    out[#out + 1] = parts[index]
  end
  return table.concat(out)
end

local function trim_leading_zeros(text)
  local trimmed = text:gsub("^0+", "")
  return trimmed == "" and "0" or trimmed
end

local function char_value(char)
  local byte = string.byte(char)
  if not byte then
    return nil
  end
  if byte >= string.byte("0") and byte <= string.byte("9") then
    return byte - string.byte("0")
  end
  local lower_byte = string.byte(string.lower(char))
  if lower_byte >= string.byte("a") and lower_byte <= string.byte("f") then
    return lower_byte - string.byte("a") + 10
  end
end

local function digit_char(value, uppercase)
  if value < 10 then
    return string.char(string.byte("0") + value)
  end
  return string.char((uppercase and string.byte("A") or string.byte("a")) + value - 10)
end

local function valid_digits(text, radix)
  if text == "" then
    return false
  end
  for index = 1, #text do
    local value = char_value(text:sub(index, index))
    if not value or value >= radix then
      return false
    end
  end
  return true
end

local function compare_unsigned(left, right)
  left, right = trim_leading_zeros(left), trim_leading_zeros(right)
  if #left ~= #right then
    return #left < #right and -1 or 1
  end
  return left == right and 0 or (left < right and -1 or 1)
end

local function add_unsigned(left, right, radix)
  local carry, parts, li, ri = 0, {}, #left, #right
  while li > 0 or ri > 0 or carry > 0 do
    local lv = li > 0 and char_value(left:sub(li, li)) or 0
    local rv = ri > 0 and char_value(right:sub(ri, ri)) or 0
    local total = lv + rv + carry
    parts[#parts + 1] = digit_char(total % radix, false)
    carry, li, ri = math.floor(total / radix), li - 1, ri - 1
  end
  return reverse_concat(parts)
end

local function sub_unsigned(left, right, radix)
  local borrow, parts, li, ri = 0, {}, #left, #right
  while li > 0 do
    local lv = char_value(left:sub(li, li)) - borrow
    local rv = ri > 0 and char_value(right:sub(ri, ri)) or 0
    if lv < rv then
      lv, borrow = lv + radix, 1
    else
      borrow = 0
    end
    parts[#parts + 1] = digit_char(lv - rv, false)
    li, ri = li - 1, ri - 1
  end
  return trim_leading_zeros(reverse_concat(parts))
end

local function int_to_base(value, radix)
  if value == 0 then
    return "0"
  end
  local parts = {}
  while value > 0 do
    parts[#parts + 1] = digit_char(value % radix, false)
    value = math.floor(value / radix)
  end
  return reverse_concat(parts)
end

local function pad_signed_decimal(is_negative, digits, width)
  local zeros = math.max(width - (is_negative and 1 or 0) - #digits, 0)
  return (is_negative and "-" or "") .. string.rep("0", zeros) .. digits
end

local function restore_separators(original, replacement, radix, indexes)
  for _, rtl_index in ipairs(indexes) do
    if rtl_index < #replacement then
      local insert_at = #replacement - rtl_index
      if insert_at > 0 then
        replacement = replacement:sub(1, insert_at) .. "_" .. replacement:sub(insert_at + 1)
      end
    end
  end
  if #replacement > #original and #indexes > 0 then
    local spacing = #indexes >= 2 and (indexes[#indexes] - indexes[#indexes - 1] - 1) or indexes[1]
    local prefix_length = radix == 10 and 0 or 2
    local first = replacement:find("_", 1, true)
    if first then
      local insert_at = first - 1
      while insert_at - prefix_length > spacing do
        insert_at = insert_at - spacing
        replacement = replacement:sub(1, insert_at) .. "_" .. replacement:sub(insert_at + 1)
      end
    end
  end
  return replacement
end

function M.increment(text, amount)
  if text == "" or text:sub(1, 1) == "_" or text:sub(-1) == "_" then
    return nil
  end
  local radix = text:sub(1, 2) == "0x" and 16 or text:sub(1, 2) == "0o" and 8 or text:sub(1, 2) == "0b" and 2 or 10
  local indexes = {}
  for index = #text, 1, -1 do
    if text:sub(index, index) == "_" then
      indexes[#indexes + 1] = #text - index
    end
  end
  local word = (text:gsub("_", ""))
  local replacement
  if radix == 10 then
    local negative = word:sub(1, 1) == "-"
    local digits = negative and word:sub(2) or word
    if not valid_digits(digits, radix) then
      return nil
    end
    local amount_digits = tostring(math.abs(amount))
    local result_negative, result_digits
    if negative then
      if amount >= 0 then
        local cmp = compare_unsigned(digits, amount_digits)
        result_negative = cmp > 0
        result_digits = cmp > 0 and sub_unsigned(digits, amount_digits, radix) or (cmp == 0 and "0" or sub_unsigned(amount_digits, digits, radix))
      else
        result_negative, result_digits = true, add_unsigned(digits, amount_digits, radix)
      end
    elseif amount >= 0 then
      result_negative, result_digits = false, add_unsigned(digits, amount_digits, radix)
    else
      local cmp = compare_unsigned(digits, amount_digits)
      result_negative = cmp < 0
      result_digits = cmp > 0 and sub_unsigned(digits, amount_digits, radix) or (cmp == 0 and "0" or sub_unsigned(amount_digits, digits, radix))
    end
    local width = #word - #indexes + (negative and not result_negative and -1 or 0) + (not negative and result_negative and 1 or 0)
    replacement = (word:sub(1, 1) == "0" or word:sub(1, 2) == "-0") and pad_signed_decimal(result_negative, result_digits, width) or ((result_negative and "-" or "") .. result_digits)
  else
    local digits = word:sub(3)
    if not valid_digits(digits, radix) then
      return nil
    end
    local result_digits
    if amount >= 0 then
      result_digits = add_unsigned(digits, int_to_base(amount, radix), radix)
    else
      local amount_digits = int_to_base(-amount, radix)
      result_digits = compare_unsigned(digits, amount_digits) <= 0 and "0" or sub_unsigned(digits, amount_digits, radix)
    end
    local width = #text - 2 - #indexes
    result_digits = string.rep("0", math.max(width - #result_digits, 0)) .. result_digits
    if radix == 16 then
      local lower, upper = 0, 0
      for index = 1, #digits do
        local char = digits:sub(index, index)
        lower, upper = lower + (char:match("%l") and 1 or 0), upper + (char:match("%u") and 1 or 0)
      end
      if upper > lower then
        result_digits = string.upper(result_digits)
      end
    end
    replacement = word:sub(1, 2) .. result_digits
  end
  return restore_separators(text, replacement, radix, indexes)
end

return M
