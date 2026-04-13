local M = {}

function M.new(opts)
  local state = opts.state
  local state_module = opts.state_module

  local registers = {
    default_yank_register = '"',
  }

  local stored = {}
  local selected = nil
  local visible_static_registers = { '_', '#', '.', '%', '+', '*' }
  local static_descriptions = {
    ['+'] = "<system clipboard>",
    ['*'] = "<primary clipboard>",
    ['_'] = "<empty>",
    ['#'] = "<selection indices>",
    ['.'] = "<selection contents>",
    ['%'] = "<document path>",
  }

  local function current_entries()
    return state.current_entries()
  end

  local function current_selection_texts()
    local values = {}
    for _, entry in ipairs(current_entries()) do
      values[#values + 1] = state_module.get_entry_text(entry)
    end
    return values
  end

  local function clipboard_contents(name)
    return vim.fn.getreg(name)
  end

  local function joined_contents(values)
    return table.concat(values, "\n")
  end

  local function normalize_name(name)
    return name or registers.default_yank_register
  end

  local function is_read_only(name)
    return name == '#' or name == '.' or name == '%'
  end

  local function is_static_register(name)
    return static_descriptions[name] ~= nil
  end

  local function is_user_register(name)
    return not is_static_register(name) and name:match("^[%w]$") ~= nil
  end

  local function preview_values(values)
    if not values or #values == 0 then
      return nil
    end

    local preview = {}
    local last_index = math.min(#values, 2)
    for index = 1, last_index do
      preview[index] = values[index]:gsub("%s+", " ")
    end

    local text = table.concat(preview, " | ")
    if #values > last_index then
      text = text .. string.format(" | +%d more", #values - last_index)
    end

    if #text > 48 then
      text = text:sub(1, 45) .. "..."
    end

    return text
  end

  local function first_value_preview(values)
    if not values or #values == 0 then
      return nil
    end

    local text = values[1]:gsub("%s+", " ")
    if #values > 1 then
      text = text .. string.format(" | +%d more", #values - 1)
    end

    if #text > 48 then
      text = text:sub(1, 45) .. "..."
    end

    return text
  end

  local function preview_read(name)
    if name == '+' or name == '*' then
      return vim.deepcopy(stored[name] or {})
    end

    return registers.read(name)
  end

  function registers.select(name)
    selected = name
  end

  function registers.selected()
    return selected
  end

  function registers.take_selected()
    local name = selected
    selected = nil
    return name
  end

  function registers.clear_selected()
    selected = nil
  end

  function registers.selectable_names()
    local names = {}
    for byte = 33, 126 do
      names[#names + 1] = string.char(byte)
    end
    return names
  end

  function registers.which_key_entries(select_fn)
    local entries = {}

    for _, name in ipairs(visible_static_registers) do
      entries[#entries + 1] = {
        name,
        function()
          select_fn(name)
        end,
        desc = static_descriptions[name],
      }
    end

    local default_values = preview_read('"')
    if #default_values > 0 then
      entries[#entries + 1] = {
        '"',
        function()
          select_fn('"')
        end,
        desc = string.format('register ": %s', first_value_preview(default_values)),
      }
    end

    local user_names = {}
    for name, values in pairs(stored) do
      if is_user_register(name) and values and #values > 0 then
        user_names[#user_names + 1] = name
      end
    end
    table.sort(user_names)

    for _, name in ipairs(user_names) do
      entries[#entries + 1] = {
        name,
        function()
          select_fn(name)
        end,
        desc = string.format("register %s: %s", name, first_value_preview(registers.read(name))),
      }
    end

    return entries
  end

  function registers.read(name)
    name = normalize_name(name)

    if name == '_' then
      return {}
    end

    if name == '#' then
      local entries = current_entries()
      local values = {}
      for index = 1, #entries do
        values[index] = tostring(index)
      end
      return values
    end

    if name == '.' then
      return current_selection_texts()
    end

    if name == '%' then
      local path = vim.api.nvim_buf_get_name(0)
      return { path ~= "" and path or "[No Name]" }
    end

    if name == '+' or name == '*' then
      local contents = clipboard_contents(name)
      local values = stored[name]
      if values and (joined_contents(values) == contents or contents == "") then
        return vim.deepcopy(values)
      end

      return contents == "" and {} or { contents }
    end

    return vim.deepcopy(stored[name] or {})
  end

  function registers.write(name, values)
    name = normalize_name(name)
    values = vim.deepcopy(values or {})

    if name == '_' then
      return true
    end

    if is_read_only(name) then
      return nil, string.format("Register [%s] is not writable", name)
    end

    stored[name] = values

    if name == '+' or name == '*' then
      vim.fn.setreg(name, joined_contents(values), "v")
    end

    return true
  end

  return registers
end

return M
