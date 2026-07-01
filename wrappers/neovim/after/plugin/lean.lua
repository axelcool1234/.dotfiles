local infoview = require("lean.infoview")

require("lean").setup({ mappings = true })

local hover_mapping_group = vim.api.nvim_create_augroup("AxelLeanHoverMappings", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = hover_mapping_group,
  pattern = "lean",
  callback = function(args)
    vim.keymap.set("n", "<leader>k", "<cmd>LeanHover<CR>", {
      buffer = args.buf,
      silent = true,
      desc = "Show interactive hover information",
    })
  end,
})

local autoclose_paused = {}
local sync_infoview
local quit_abbrevs = {
  { from = "q", to = "LeanSmartQuit" },
  { from = "q!", to = "LeanSmartQuit!" },
  { from = "quit", to = "LeanSmartQuit" },
  { from = "quit!", to = "LeanSmartQuit!" },
}

local function current_tab_infoview(tabpage)
  return infoview._by_tabpage[tabpage or vim.api.nvim_get_current_tabpage()]
end

local function current_filetype()
  return vim.bo.filetype
end

local function should_use_lean_smart_quit()
  local ok, filetype = pcall(current_filetype)
  return ok and filetype == "lean"
end

local function current_infoview_window(tabpage)
  local iv = current_tab_infoview(tabpage)
  if not iv or not iv.window or iv.__separate_tab or not iv.window:is_valid() then
    return nil, nil
  end

  return iv, iv.window.id
end

local function count_lean_windows(tabpage)
  local count = 0

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "lean" then
      count = count + 1
    end
  end

  return count
end

local function first_modified_listed_buffer(excluded)
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if info.bufnr ~= excluded and info.changed == 1 and vim.api.nvim_buf_is_valid(info.bufnr) then
      return info.bufnr
    end
  end

  return nil
end

local function emit_quit_warning(bufnr)
  vim.api.nvim_err_writeln("E37: No write since last change")

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    name = "[No Name]"
  else
    name = vim.fn.fnamemodify(name, ":t")
  end

  vim.api.nvim_err_writeln(string.format('E162: No write since last change for buffer "%s"', name))
end

local function with_autoclose_paused(tabpage, callback)
  autoclose_paused[tabpage] = true
  local ok, result = pcall(callback)
  autoclose_paused[tabpage] = nil
  return ok, result
end

local function in_two_pane_lean_layout(tabpage)
  local _, infoview_winid = current_infoview_window(tabpage)
  if not infoview_winid then
    return false, nil
  end

  local wins = vim.api.nvim_tabpage_list_wins(tabpage)
  if #wins ~= 2 then
    return false, nil
  end

  local current = vim.api.nvim_get_current_win()
  if current == infoview_winid or current_filetype() ~= "lean" then
    return false, nil
  end

  return true, infoview_winid
end

local function close_orphaned_infoview(tabpage)
  if not vim.api.nvim_tabpage_is_valid(tabpage) then
    return
  end

  if autoclose_paused[tabpage] then
    return
  end

  local iv, infoview_winid = current_infoview_window(tabpage)
  if not iv then
    return
  end

  if count_lean_windows(tabpage) > 0 then
    return
  end

  local wins = vim.api.nvim_tabpage_list_wins(tabpage)
  if #wins == 1 and wins[1] == infoview_winid then
    pcall(vim.cmd, "quit")
    return
  end

  infoview.close()
end

local function lean_smart_quit(force)
  local quit_cmd = force and "quit!" or "quit"
  local tabpage = vim.api.nvim_get_current_tabpage()
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()
  local should_pair_quit, infoview_winid = in_two_pane_lean_layout(tabpage)

  if force and should_pair_quit then
    local target = first_modified_listed_buffer(current_buf)
    if target then
      with_autoclose_paused(tabpage, function()
        vim.cmd("edit!")
        vim.api.nvim_win_set_buf(current_win, target)
      end)
      vim.schedule(function()
        emit_quit_warning(target)
      end)
      return
    end
  end

  local ok, err = with_autoclose_paused(tabpage, function()
    vim.cmd(quit_cmd)
  end)

  if not ok then
    vim.schedule(function()
      if vim.api.nvim_tabpage_is_valid(tabpage) then
        sync_infoview(tabpage)
      end
      vim.api.nvim_err_writeln(err)
    end)
    return
  end

  if not should_pair_quit or not vim.api.nvim_tabpage_is_valid(tabpage) then
    return
  end

  local iv = current_tab_infoview(tabpage)
  if not iv or not iv.window or not iv.window:is_valid() then
    return
  end

  local wins = vim.api.nvim_tabpage_list_wins(tabpage)
  if #wins == 1 and wins[1] == infoview_winid then
    iv.window.o.winfixbuf = false
    local ok, err = pcall(vim.cmd, quit_cmd)
    if not ok then
      local modified = first_modified_listed_buffer()
      if modified then
        vim.api.nvim_set_current_buf(modified)
      end
      vim.schedule(function()
        emit_quit_warning(modified)
      end)
    end
  end
end

sync_infoview = function(tabpage)
  if not vim.api.nvim_tabpage_is_valid(tabpage) then
    return
  end

  if current_filetype() == "lean" then
    local iv = current_tab_infoview(tabpage)
    if not iv or not iv.window or not iv.window:is_valid() then
      infoview.open()
    end
    return
  end

  close_orphaned_infoview(tabpage)
end

local lifecycle_group = vim.api.nvim_create_augroup("AxelLeanInfoviewLifecycle", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "FileType" }, {
  group = lifecycle_group,
  callback = function()
    local tabpage = vim.api.nvim_get_current_tabpage()
    vim.schedule(function()
      sync_infoview(tabpage)
    end)
  end,
})

vim.api.nvim_create_autocmd("WinClosed", {
  group = lifecycle_group,
  callback = function()
    local tabpage = vim.api.nvim_get_current_tabpage()
    vim.schedule(function()
      close_orphaned_infoview(tabpage)
    end)
  end,
})

_G.axelcool1234_should_use_lean_smart_quit = should_use_lean_smart_quit

vim.api.nvim_create_user_command("LeanSmartQuit", function(opts)
  lean_smart_quit(opts.bang)
end, { bang = true })

for _, entry in ipairs(quit_abbrevs) do
  vim.cmd(string.format(
    [[cnoreabbrev <expr> %s getcmdtype() ==# ':' && getcmdline() ==# '%s' && v:lua.axelcool1234_should_use_lean_smart_quit() ? '%s' : '%s']],
    entry.from,
    entry.from,
    entry.to,
    entry.from
  ))
end
