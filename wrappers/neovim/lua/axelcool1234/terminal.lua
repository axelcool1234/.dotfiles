local M = {}

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

  local origin_tab = vim.api.nvim_get_current_tabpage()
  vim.cmd("tabnew")
  local tabpage = vim.api.nvim_get_current_tabpage()
  local term_buf = vim.api.nvim_get_current_buf()

  vim.bo[term_buf].bufhidden = "wipe"
  vim.bo[term_buf].buflisted = false

  vim.fn.termopen(command, {
    env = opts.env,
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_tabpage_is_valid(origin_tab) then
          vim.api.nvim_set_current_tabpage(origin_tab)
        end

        if vim.api.nvim_tabpage_is_valid(tabpage) then
          vim.api.nvim_set_current_tabpage(tabpage)
          vim.cmd("silent! tabclose!")
        end

        if vim.api.nvim_buf_is_valid(term_buf) and vim.api.nvim_buf_is_loaded(term_buf) then
          vim.api.nvim_buf_delete(term_buf, { force = true })
        end

        if opts.on_exit then
          opts.on_exit()
        end
      end)
    end,
  })

  vim.cmd("startinsert")
end

function M.open_jjui()
  require("axelcool1234.jjui").open()
end

return M
