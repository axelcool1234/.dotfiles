local M = {}

local state = {
  origin_tab = nil,
  tabpage = nil,
  term_buf = nil,
}

local function has_command(command)
  if vim.fn.executable(command) == 1 then
    return true
  end

  vim.notify(command .. " is not available in PATH", vim.log.levels.WARN)
  return false
end

local function valid_tab(tabpage)
  return tabpage ~= nil and vim.api.nvim_tabpage_is_valid(tabpage)
end

local function valid_buf(buffer)
  return buffer ~= nil and vim.api.nvim_buf_is_valid(buffer) and vim.api.nvim_buf_is_loaded(buffer)
end

local function ensure_servername()
  if vim.v.servername ~= nil and vim.v.servername ~= "" then
    return vim.v.servername
  end

  return vim.fn.serverstart(vim.fs.joinpath(vim.fn.stdpath("run"), "jjui.sock"))
end

local function cleanup_session()
  local origin_tab = state.origin_tab
  local tabpage = state.tabpage
  local term_buf = state.term_buf

  state.origin_tab = nil
  state.tabpage = nil
  state.term_buf = nil

  if valid_tab(origin_tab) then
    vim.api.nvim_set_current_tabpage(origin_tab)
  end

  if valid_tab(tabpage) then
    vim.api.nvim_set_current_tabpage(tabpage)
    vim.cmd("silent! tabclose!")
  end

  if valid_buf(term_buf) then
    vim.api.nvim_buf_delete(term_buf, { force = true })
  end

  if valid_tab(origin_tab) then
    vim.api.nvim_set_current_tabpage(origin_tab)
  end
end

function M.open_target(path, line)
  if path == nil or path == "" then
    vim.notify("jjui did not provide a file to open", vim.log.levels.WARN)
    return
  end

  vim.schedule(function()
    local origin_tab = state.origin_tab

    if valid_tab(origin_tab) then
      vim.api.nvim_set_current_tabpage(origin_tab)
    end

    vim.cmd("drop " .. vim.fn.fnameescape(path))

    local target_line = tonumber(line)
    if target_line ~= nil and target_line > 0 then
      local last_line = vim.api.nvim_buf_line_count(0)
      vim.api.nvim_win_set_cursor(0, { math.min(target_line, last_line), 0 })
      vim.cmd("normal! zz")
    end

    cleanup_session()
    vim.cmd("checktime")
  end)
end

function M.open()
  if valid_tab(state.tabpage) then
    vim.api.nvim_set_current_tabpage(state.tabpage)
    vim.cmd("startinsert")
    return
  end

  if not has_command("jjui") then
    return
  end

  vim.cmd("silent! writeall")

  state.origin_tab = vim.api.nvim_get_current_tabpage()

  vim.cmd("tabnew")

  state.tabpage = vim.api.nvim_get_current_tabpage()
  state.term_buf = vim.api.nvim_get_current_buf()

  vim.bo[state.term_buf].bufhidden = "wipe"
  vim.bo[state.term_buf].buflisted = false

  vim.fn.termopen({ "jjui" }, {
    env = {
      JJUI_NVIM_SERVER = ensure_servername(),
      JJUI_NVIM_PROGPATH = vim.v.progpath,
    },
    on_exit = function()
      vim.schedule(function()
        cleanup_session()
        vim.cmd("checktime")
      end)
    end,
  })

  vim.cmd("startinsert")
end

return M
