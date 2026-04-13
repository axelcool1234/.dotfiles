local M = {}

local config = {
  border = "rounded",
  width = 0.8,
  height = 0.8,
}

local state = {
  buf = nil,
  win = nil,
  job = nil,
  cmd = nil,
}

local function module_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  local lua_dir = vim.fs.dirname(source)
  return vim.fs.dirname(vim.fs.dirname(lua_dir))
end

local function helper_script_path()
  return vim.fs.joinpath(module_root(), "scripts", "gh-dash-open")
end

local function ensure_servername()
  if vim.v.servername ~= nil and vim.v.servername ~= "" then
    return vim.v.servername
  end

  return vim.fn.serverstart(vim.fs.joinpath(vim.fn.stdpath("run"), "gh-dash.sock"))
end

local function config_override_path()
  return vim.fs.joinpath(vim.fn.stdpath("cache"), "gh-dash-neovim.yml")
end

local function write_override_config()
  local script = helper_script_path()
  local path = config_override_path()
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local lines = {
    "keybindings:",
    "  prs:",
    "    - key: O",
    "      name: open in current neovim",
    ('      command: sh %s "$GH_DASH_NVIM_SERVER" "$GH_DASH_NVIM_PROGPATH" pr {{ .RepoName }} {{ .PrNumber }}'):format(script),
    "  issues:",
    "    - key: O",
    "      name: open in current neovim",
    ('      command: sh %s "$GH_DASH_NVIM_SERVER" "$GH_DASH_NVIM_PROGPATH" issue {{ .RepoName }} {{ .IssueNumber }}'):format(script),
    "  notifications:",
    "    - key: O",
    "      name: open in current neovim",
    ('      command: sh %s "$GH_DASH_NVIM_SERVER" "$GH_DASH_NVIM_PROGPATH" {{- if index . "PrNumber" -}}pr {{ .RepoName }} {{ .PrNumber }}{{- else if index . "IssueNumber" -}}issue {{ .RepoName }} {{ .IssueNumber }}{{- end -}}'):format(script),
  }

  vim.fn.writefile(lines, path)
  return path
end

local function refresh_lualine()
  local ok, lualine = pcall(require, "lualine")
  if ok then
    lualine.refresh({
      force = true,
      place = { "statusline" },
      trigger = "autocmd",
    })
  end
end

local function resolve_cmd()
  if vim.fn.executable("gh-dash") == 1 then
    return { "gh-dash" }
  end

  if vim.fn.executable("gh") == 1 then
    return { "gh", "dash" }
  end

  return nil
end

local function cleanup_buffer()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.buf = nil
  state.job = nil
  state.cmd = nil
  refresh_lualine()
end

local function close_window()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  refresh_lualine()
end

local function ensure_buffer()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  state.buf = vim.api.nvim_create_buf(false, false)
  vim.bo[state.buf].bufhidden = "hide"
  vim.bo[state.buf].swapfile = false
  vim.bo[state.buf].filetype = "gh_dash"

  vim.keymap.set("t", "<Esc>", function()
    vim.schedule(function()
      M.toggle()
    end)
  end, { buffer = state.buf, silent = true, desc = "Hide gh-dash" })

  vim.keymap.set("n", "q", function()
    M.toggle()
  end, { buffer = state.buf, silent = true, desc = "Hide gh-dash" })
end

local function open_window()
  local width = math.floor(vim.o.columns * config.width)
  local height = math.floor(vim.o.lines * config.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = config.border,
  })

  vim.cmd.startinsert()
  refresh_lualine()
end

local function render_missing_dependency_message(lines)
  ensure_buffer()
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  open_window()
end

local function start_job()
  state.cmd = resolve_cmd()
  if not state.cmd then
    render_missing_dependency_message({
      "No gh-dash command found.",
      "",
      "Install either:",
      "  nix profile install nixpkgs#gh-dash",
      "or",
      "  gh extension install dlvhdr/gh-dash",
    })
    return false
  end

  ensure_buffer()
  open_window()

  if state.job then
    return true
  end

  state.job = vim.fn.termopen(state.cmd, {
    cwd = vim.uv.cwd(),
    env = {
      GH_DASH_CONFIG = write_override_config(),
      GH_DASH_NVIM_SERVER = ensure_servername(),
      GH_DASH_NVIM_PROGPATH = vim.v.progpath,
    },
    on_exit = function()
      vim.schedule(function()
        close_window()
        cleanup_buffer()
      end)
    end,
  })

  return true
end

function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})
end

function M.open()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    open_window()
    return
  end

  start_job()
end

function M.hide()
  close_window()
end

function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    M.hide()
  else
    M.open()
  end
end

function M.open_target(kind, repo, number)
  if kind ~= "issue" and kind ~= "pr" then
    vim.notify("Unsupported gh-dash target type: " .. tostring(kind), vim.log.levels.ERROR)
    return
  end

  local issue_number = tonumber(number)
  if not issue_number then
    vim.notify("Missing gh-dash target number", vim.log.levels.ERROR)
    return
  end

  M.hide()

  local target_path = kind == "pr" and "pull" or "issues"
  local url = ("https://github.com/%s/%s/%d"):format(repo, target_path, issue_number)
  vim.cmd("Octo " .. url)
end

function M.statusline()
  if state.job and not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return "[gh-dash]"
  end

  return ""
end

function M.status()
  return {
    function()
      return M.statusline()
    end,
    cond = function()
      return M.statusline() ~= ""
    end,
    icon = "",
    color = { fg = "#51afef" },
  }
end

return M
