local M = {}

function M.get(opts)
  opts = opts or {}
  local command = opts.kitty_path or "kitty"
  local window_id = opts.window_id or vim.env.KITTY_WINDOW_ID
  if not window_id or window_id == "" or vim.fn.executable(command) ~= 1 then
    return nil
  end

  local function try(with_window_id)
    local cmd = { command, "@", "get-colors" }
    if with_window_id then
      cmd[#cmd + 1] = "--match=id:" .. window_id
    end

    local result = vim.system(cmd, { text = true }):wait(1000)
    if result.code ~= 0 then
      return nil
    end

    local colors = {}
    for line in (result.stdout or ""):gmatch("[^\r\n]+") do
      local name, color = line:match("^(%S+)%s+(#%x%x%x%x%x%x)%s*$")
      if name then
        colors[name] = color
      end
    end
    if colors.foreground and colors.background then
      return colors
    end
  end

  local colors = try(true)
  if not colors and opts.fallback_to_current then
    colors = try(false)
  end
  return colors
end

-- Neovim reads these buffer-local overrides when the terminal opens.
function M.apply_palette(bufid, colors)
  if not colors or not bufid or not vim.api.nvim_buf_is_valid(bufid) then
    return
  end

  for index = 0, 15 do
    vim.b[bufid]["terminal_color_" .. index] = colors["color" .. index]
  end
end

return M
