local M = {}

local open_term_command = vim.fn.has("nvim-0.11") == 0 and "termopen" or "jobstart"
local paste_padding_lines = 32

local state = {
  bufid = nil,
  command_line_editing = vim.env.KITTY_SCROLLBACK_NVIM_MODE == "command_line_editing",
  command_line_input = vim.env.KITTY_SCROLLBACK_NVIM_EDIT_INPUT,
  extent = "all",
  kitty_colors = nil,
  kitty_data = nil,
  orig_columns = nil,
  orig_shell = nil,
  paste_bufid = nil,
  paste_winid = nil,
  pos = nil,
}

local function hex_to_rgb(hex)
  if not hex or hex == "none" then
    return nil
  end
  return {
    tonumber(hex:sub(2, 3), 16),
    tonumber(hex:sub(4, 5), 16),
    tonumber(hex:sub(6, 7), 16),
  }
end

local function blend(foreground, background, alpha)
  local fg = hex_to_rgb(foreground)
  local bg = hex_to_rgb(background)
  if not fg or not bg then
    return foreground or background
  end

  local function blend_channel(index)
    local value = (alpha * fg[index]) + ((1 - alpha) * bg[index])
    return math.floor(math.min(math.max(0, value), 255) + 0.5)
  end

  return string.format("#%02x%02x%02x", blend_channel(1), blend_channel(2), blend_channel(3))
end

local function darken(hex, amount, bg)
  local default_bg = vim.o.background == "dark" and "#000000" or "#ffffff"
  return blend(hex, bg or default_bg, amount)
end

local function quitall()
  if vim.fn.getcmdwintype() == "" then
    vim.cmd("quitall!")
    return
  end

  vim.cmd.quit({ bang = true })
  vim.defer_fn(function()
    vim.cmd("quitall!")
  end, 250)
end

local function shell_basename(shell)
  return vim.fn.fnamemodify(shell or vim.o.shell, ":t:r")
end

local function set_keymap(buf, mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, {
    buffer = buf,
    silent = true,
    desc = desc,
  })
end

local function notify_error(lines)
  vim.schedule(function()
    vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR)
  end)
end

local function system_checked(cmd)
  local result = vim.system(cmd):wait()
  if result.code ~= 0 then
    notify_error({
      "Kitty scrollback: command failed",
      table.concat(cmd, " "),
      result.stderr ~= "" and result.stderr or "<no stderr>",
    })
    return false, result
  end

  return true, result
end

local function get_kitty_colors()
  local function try(with_window_id)
    local cmd = {
      state.kitty_data.kitty_path,
      "@",
      "get-colors",
    }
    if with_window_id then
      cmd[#cmd + 1] = "--match=id:" .. state.kitty_data.window_id
    end

    local result = vim.system(cmd, { text = true }):wait()
    if result.code ~= 0 then
      return false, result
    end

    local colors = {}
    for line in (result.stdout or ""):gmatch("[^\r\n]+") do
      local parts = {}
      for part in line:gmatch("%S+") do
        parts[#parts + 1] = part
      end
      if #parts >= 2 then
        colors[parts[1]] = parts[2]
      end
    end
    return true, colors
  end

  local ok, colors = try(true)
  if ok then
    return colors
  end

  ok, colors = try(false)
  if ok then
    return colors
  end

  return nil
end

local function apply_terminal_palette(bufid)
  if not state.kitty_colors or not bufid or not vim.api.nvim_buf_is_valid(bufid) then
    return
  end

  vim.api.nvim_buf_call(bufid, function()
    for index = 0, 15 do
      vim.b["terminal_color_" .. index] = state.kitty_colors["color" .. index]
    end
  end)
end

local function normalize_color(color)
  if type(color) == "number" then
    return string.format("#%06x", color)
  end

  if color == "none" then
    return nil
  end

  return color
end

local function current_highlight(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if not ok or not hl or not next(hl) then
    return {}
  end
  return hl
end

local function set_scrollback_highlights()
  if not state.kitty_colors then
    return
  end

  local normal = {
    default = false,
    fg = state.kitty_colors.foreground,
    bg = state.kitty_colors.background,
  }

  local normal_source = current_highlight("Normal")
  local normal_fg = normalize_color(normal_source.fg) or state.kitty_colors.foreground
  local normal_bg = normalize_color(normal_source.bg) or state.kitty_colors.background
  local visual = {
    default = false,
    bg = darken(normal_fg, 0.2, normal_bg),
  }

  local paste_bg = state.kitty_colors.background
  local border_fg = darken(state.kitty_colors.foreground, 0.3, paste_bg)

  vim.api.nvim_set_hl(0, "Axelcool1234KittyScrollbackNormal", normal)
  vim.api.nvim_set_hl(0, "Axelcool1234KittyScrollbackVisual", visual)
  vim.api.nvim_set_hl(0, "Axelcool1234KittyScrollbackPasteNormal", {
    default = false,
    bg = paste_bg,
  })
  vim.api.nvim_set_hl(0, "Axelcool1234KittyScrollbackPasteWinBar", {
    default = false,
    bg = border_fg,
    fg = paste_bg,
  })

  apply_terminal_palette(state.bufid)

  vim.api.nvim_set_option_value(
    "winhighlight",
    table.concat({
      "Normal:Axelcool1234KittyScrollbackNormal",
      "Visual:Axelcool1234KittyScrollbackVisual",
    }, ","),
    { scope = "local", win = 0 }
  )
end

local function line_offset()
  local tab_offset = 0
  if vim.o.showtabline >= 2 or (vim.o.showtabline == 1 and vim.fn.tabpagenr("$") > 1) then
    tab_offset = 1
  end

  local winbar_offset = vim.o.winbar ~= "" and 1 or 0
  return tab_offset + winbar_offset
end

local function set_env()
  vim.env.KITTY_KITTEN_RUN_MODULE = nil
end

local function set_options()
  state.orig_shell = vim.o.shell

  vim.o.virtualedit = "all"
  vim.o.termguicolors = true
  vim.opt.shortmess:append("AI")
  vim.o.scrolloff = 0
  vim.o.number = false
  vim.o.relativenumber = false
  vim.o.list = false
  vim.o.showmode = false
  vim.o.ignorecase = true
  vim.o.smartcase = true
  vim.o.cursorline = false
  vim.o.cursorcolumn = false
  vim.opt.fillchars = {
    eob = " ",
  }
  vim.o.lazyredraw = false
  vim.o.hidden = true
  vim.o.modifiable = true
  vim.o.wrap = false
  vim.o.report = 999999
end

local function disable_term_close_autocmd()
  if vim.fn.has("nvim-0.12") == 1 then
    vim.api.nvim_clear_autocmds({ group = "nvim.terminal", event = "TermClose" })
  end
end

local function set_cursor_position()
  local d = state.kitty_data
  local tab_and_winbar = line_offset()
  local x = d.cursor_x - 1
  local y = d.cursor_y - 1 - tab_and_winbar
  local scrolled_by = d.scrolled_by
  local lines = d.lines - tab_and_winbar

  if vim.fn.has("nvim-0.12") == 1 then
    lines = lines - 1
  end

  if y < 0 then
    lines = lines + math.abs(y)
    y = 0
  end

  local last_line = vim.fn.line("$")
  local orig_virtualedit = vim.o.virtualedit
  local orig_scrolloff = vim.o.scrolloff
  vim.o.scrolloff = 0
  vim.o.virtualedit = "all"

  vim.fn.cursor(last_line, 1)

  if lines ~= 0 then
    vim.cmd.normal({ lines .. "k", bang = true })
  end
  if y ~= 0 then
    vim.cmd.normal({ y .. "j", bang = true })
  end
  if x ~= 0 then
    vim.cmd.normal({ x .. "l", bang = true })
  end
  if scrolled_by > 0 then
    vim.cmd.normal({
      vim.api.nvim_replace_termcodes(scrolled_by .. "<C-y>", true, false, true),
      bang = true,
    })
  end

  state.pos = {
    cursor_line = vim.fn.line("."),
    win_first_line = vim.fn.line("w0"),
    col = x,
  }

  vim.o.scrolloff = orig_scrolloff
  vim.o.virtualedit = orig_virtualedit
end

local function trim_trailing_blank_lines(lines)
  local last = #lines
  while last > 0 and lines[last] == "" do
    last = last - 1
  end

  local trimmed = {}
  for index = 1, last do
    trimmed[index] = lines[index]
  end
  return trimmed
end

local function send_chunks_to_kitty(chunks, execute)
  local filtered = vim.tbl_filter(function(chunk)
    return chunk ~= nil and chunk ~= ""
  end, chunks)

  local text = table.concat(filtered, "\r")
  local ok = system_checked({
    state.kitty_data.kitty_path,
    "@",
    "send-text",
    "--match=id:" .. state.kitty_data.window_id,
    "--bracketed-paste=auto",
    text,
  })
  if not ok then
    return
  end

  if execute then
    ok = system_checked({
      state.kitty_data.kitty_path,
      "@",
      "send-text",
      "--match=id:" .. state.kitty_data.window_id,
      "--bracketed-paste=disable",
      "\r",
    })
    if not ok then
      return
    end
  end

  quitall()
end

local function read_register_chunks(register_name)
  local helix = require("axelcool1234.helix")
  return helix.read_register(register_name)
end

local function send_register(register_name)
  local chunks = read_register_chunks(register_name)
  if #chunks == 0 then
    vim.notify(
      string.format("Kitty scrollback: register %s is empty", register_name),
      vim.log.levels.WARN
    )
    return
  end

  send_chunks_to_kitty(chunks, false)
end

local function close_paste_window()
  if state.paste_winid and vim.api.nvim_win_is_valid(state.paste_winid) then
    vim.api.nvim_win_close(state.paste_winid, true)
  end
  state.paste_winid = nil
end

local function ensure_paste_padding(buf)
  local line_count = vim.api.nvim_buf_line_count(buf)
  local pad = {}
  for _ = 1, paste_padding_lines do
    pad[#pad + 1] = ""
  end
  vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, pad)
end

local function paste_buffer_name()
  return vim.fn.tempname() .. ".axel_kitty_pastebuf"
end

local function paste_window_height()
  return math.max(12, math.floor(vim.o.lines * 0.38))
end

local function paste_window_label()
  if state.command_line_editing then
    return " command-line edit "
  end
  return " kitty paste "
end

local function current_content_end(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local last = #lines
  while last > 0 and lines[last] == "" do
    last = last - 1
  end
  return last
end

local function send_paste_buffer_to_kitty()
  if not state.paste_bufid or not vim.api.nvim_buf_is_valid(state.paste_bufid) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(state.paste_bufid, 0, current_content_end(state.paste_bufid), false)
  send_chunks_to_kitty(trim_trailing_blank_lines(lines), false)
end

local function open_paste_window(start_insert)
  if not state.paste_bufid or not vim.api.nvim_buf_is_valid(state.paste_bufid) then
    state.paste_bufid = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(state.paste_bufid, paste_buffer_name())
    vim.api.nvim_set_option_value("filetype", shell_basename(state.kitty_data.shell), { buf = state.paste_bufid })
    vim.api.nvim_set_option_value("swapfile", false, { buf = state.paste_bufid })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.paste_bufid })
    vim.api.nvim_create_autocmd("BufWriteCmd", {
      group = vim.api.nvim_create_augroup("Axelcool1234KittyScrollbackPasteWrite", { clear = true }),
      buffer = state.paste_bufid,
      callback = send_paste_buffer_to_kitty,
    })
    set_keymap(state.paste_bufid, "n", "gq", close_paste_window, "Kitty scrollback: close paste buffer")
    set_keymap(state.paste_bufid, { "n", "i", "t" }, "<C-c>", quitall, "Kitty scrollback: quit")
  end

  if not state.paste_winid or not vim.api.nvim_win_is_valid(state.paste_winid) then
    vim.cmd("botright split")
    state.paste_winid = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(state.paste_winid, state.paste_bufid)
    vim.api.nvim_win_set_height(state.paste_winid, paste_window_height())
    vim.api.nvim_set_option_value("winfixheight", true, { win = state.paste_winid })
    ensure_paste_padding(state.paste_bufid)
    if state.kitty_colors then
      vim.api.nvim_set_option_value(
        "winhighlight",
        "Normal:Axelcool1234KittyScrollbackPasteNormal,WinBar:Axelcool1234KittyScrollbackPasteWinBar",
        { win = state.paste_winid, scope = "local" }
      )
    end
    vim.api.nvim_set_option_value("winbar", paste_window_label(), { win = state.paste_winid, scope = "local" })
  else
    vim.api.nvim_set_current_win(state.paste_winid)
  end

  local last = current_content_end(state.paste_bufid)
  vim.api.nvim_win_set_cursor(state.paste_winid, { math.max(1, last), 0 })

  if start_insert then
    vim.cmd.startinsert({ bang = true })
  end
end

local function extent_for_config(config_name)
  if config_name == "ksb_builtin_last_cmd_output" then
    return "last_cmd_output"
  end
  if config_name == "ksb_builtin_last_visited_cmd_output" then
    return "last_visited_cmd_output"
  end
  return "all"
end

local function get_scrollback_command(extent)
  local scrollback_cmd = ([[%s @ get-text --match="id:%s" --ansi --clear-selection --add-wrap-markers --extent=%s]]):format(
    state.kitty_data.kitty_path,
    state.kitty_data.window_id,
    extent
  )
  local sed_cmd = [[sed -E -e 's/\r//g' -e 's/$/\x1b[0m/g']]
  local flush_stdout_cmd = state.kitty_data.kitty_path .. [[ +runpy 'sys.stdout.flush()']]
  local full_cmd = scrollback_cmd .. " | " .. sed_cmd .. " && " .. flush_stdout_cmd
  if vim.fn.has("nvim-0.12") == 0 then
    full_cmd = full_cmd .. [[ && printf "\x1b]2;"]]
  end
  return full_cmd
end

local function defer_resize_term(min_cols)
  local orig_columns = vim.o.columns
  if vim.o.columns < min_cols then
    vim.defer_fn(function()
      vim.o.columns = min_cols
      vim.api.nvim_set_option_value("columns", min_cols, { scope = "global" })
    end, 0)
  end
  return orig_columns
end

local function on_scrollback_ready()
  vim.api.nvim_set_option_value("swapfile", false, { buf = state.bufid })
  vim.api.nvim_set_option_value("filetype", "kitty-scrollback", { buf = state.bufid })

  local term_buf_name = vim.api.nvim_buf_get_name(state.bufid)
  term_buf_name = term_buf_name:gsub("^(term://.-:).*", "%1kitty-scrollback")
  vim.api.nvim_buf_set_name(state.bufid, term_buf_name)
  set_scrollback_highlights()

  if state.extent == "all" then
    set_cursor_position()
  end

  set_keymap(state.bufid, "n", "gq", quitall, "Kitty scrollback: close")
  set_keymap(state.bufid, { "n", "i", "t" }, "<C-c>", quitall, "Kitty scrollback: quit")
  set_keymap(state.bufid, "n", "i", function()
    open_paste_window(true)
  end, "Kitty scrollback: compose in paste buffer")
  set_keymap(state.bufid, "n", "a", function()
    open_paste_window(true)
  end, "Kitty scrollback: compose in paste buffer")
  set_keymap(state.bufid, "n", "p", function()
    send_register('"')
  end, "Kitty scrollback: send default register to Kitty")
  set_keymap(state.bufid, "n", "<leader>p", function()
    send_register("+")
  end, "Kitty scrollback: send clipboard register to Kitty")

  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("Axelcool1234KittyScrollbackBufEnter", { clear = true }),
    callback = function(event)
      if event.buf == state.bufid then
        close_paste_window()
      end
    end,
  })

  if state.command_line_editing then
    vim.schedule(function()
      if not state.command_line_input or state.command_line_input == "" then
        vim.notify(
          "Kitty scrollback: missing command-line edit input file",
          vim.log.levels.ERROR
        )
        return
      end

      local input_lines = vim.fn.readfile(state.command_line_input)
      open_paste_window(#input_lines == 1 and input_lines[1] == "")
      vim.api.nvim_buf_set_lines(state.paste_bufid, 0, -1, false, input_lines)
      ensure_paste_padding(state.paste_bufid)
      vim.api.nvim_win_set_cursor(state.paste_winid, { math.max(1, #input_lines), 0 })
    end)
  end
end

local function launch_scrollback()
  local buf_lines = vim.api.nvim_buf_get_lines(0, 0, 1, false)
  local no_buf_content = vim.api.nvim_buf_line_count(0) == 1 and buf_lines[1] == ""
  if no_buf_content then
    state.bufid = vim.api.nvim_get_current_buf()
  else
    state.bufid = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_current_buf(state.bufid)
  end

  disable_term_close_autocmd()

  apply_terminal_palette(state.bufid)

  state.orig_columns = defer_resize_term(300)
  vim.o.shell = "sh"

  local full_cmd = get_scrollback_command(state.extent)
  local open_term_fn = vim.fn[open_term_command]
  local open_term_options = {
    stdout_buffered = true,
    stderr_buffered = true,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        vim.o.columns = state.orig_columns
        vim.o.shell = state.orig_shell
        if exit_code ~= 0 then
          notify_error({
            "Kitty scrollback: failed to load scrollback contents",
            full_cmd,
          })
          return
        end
        on_scrollback_ready()
      end)
    end,
  }
  if open_term_command == "jobstart" then
    open_term_options.term = true
  end

  local ok, err = pcall(open_term_fn, full_cmd, open_term_options)
  if not ok then
    vim.o.shell = state.orig_shell
    notify_error({
      "Kitty scrollback: failed to start terminal job",
      tostring(err),
    })
  end
end

function M.setup_and_launch(kitty_data_str)
  state.kitty_data = vim.fn.json_decode(kitty_data_str)
  state.extent = extent_for_config(state.kitty_data.kitty_scrollback_config)
  state.kitty_colors = get_kitty_colors()
  state.paste_bufid = nil
  state.paste_winid = nil
  set_env()
  set_options()

  if state.kitty_data.kitty_scrollback_config == "ksb_builtin_checkhealth" then
    vim.schedule(function()
      vim.notify("Kitty scrollback checkhealth is not implemented in the local session", vim.log.levels.WARN)
      quitall()
    end)
    return
  end

  vim.schedule(launch_scrollback)
end

return M
