local M = {}

local function read_first_line(path)
  local handle = io.open(path, "r")
  if not handle then
    return nil
  end

  local line = handle:read("*l")
  handle:close()
  return line
end

local function edit_if_selected(path)
  local selected = read_first_line(path)
  os.remove(path)

  if selected and selected ~= "" then
    vim.cmd.edit(vim.fn.fnameescape(selected))
  end
end

local function has_command(command)
  if vim.fn.executable(command) == 1 then
    return true
  end

  vim.notify(command .. " is not available in PATH", vim.log.levels.WARN)
  return false
end

function M.run_terminal_tab(command, opts)
  opts = opts or {}

  if opts.write_all ~= false then
    vim.cmd("silent! writeall")
  end

  vim.cmd("tabnew")
  local tabpage = vim.api.nvim_get_current_tabpage()

  vim.fn.termopen(command, {
    env = opts.env,
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_tabpage_is_valid(tabpage) then
          vim.api.nvim_set_current_tabpage(tabpage)
          vim.cmd("silent! tabclose")
        end

        if opts.on_exit then
          opts.on_exit()
        end
      end)
    end,
  })

  vim.cmd("startinsert")
end

function M.open_lazygit()
  if not has_command("lazygit") then
    return
  end

  local path_file = vim.fn.tempname()
  os.remove(path_file)

  M.run_terminal_tab({ "lazygit" }, {
    env = { LAZYGIT_OPEN_PATH_FILE = path_file },
    on_exit = function()
      edit_if_selected(path_file)
      vim.cmd("checktime")
    end,
  })
end

return M
