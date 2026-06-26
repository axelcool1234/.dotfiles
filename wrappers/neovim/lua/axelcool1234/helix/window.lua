local M = {}

function M.new()
  local focus_state = nil

  local window = {}

  local function current_tab_windows()
    local wins = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local config = vim.api.nvim_win_get_config(win)
      if config.relative == "" then
        wins[#wins + 1] = win
      end
    end
    return wins
  end

  local function adjacent_window(direction)
    if not vim.tbl_contains({ "h", "j", "k", "l" }, direction) then
      return nil
    end

    local target = vim.fn.win_getid(vim.fn.winnr(direction))
    local current = vim.api.nvim_get_current_win()
    if target == 0 or target == current then
      return nil
    end

    return target
  end

  local function swap_window_state(left, right)
    local left_buffer = vim.api.nvim_win_get_buf(left)
    local right_buffer = vim.api.nvim_win_get_buf(right)
    local left_view = vim.api.nvim_win_call(left, vim.fn.winsaveview)
    local right_view = vim.api.nvim_win_call(right, vim.fn.winsaveview)

    vim.api.nvim_win_set_buf(left, right_buffer)
    vim.api.nvim_win_set_buf(right, left_buffer)

    vim.api.nvim_win_call(left, function()
      vim.fn.winrestview(right_view)
    end)
    vim.api.nvim_win_call(right, function()
      vim.fn.winrestview(left_view)
    end)
  end

  function window.transpose_splits()
    local wins = current_tab_windows()
    if #wins ~= 2 then
      vim.notify("transpose splits currently supports exactly two windows", vim.log.levels.INFO)
      return
    end

    local layout = vim.fn.winlayout()
    local kind = layout[1]
    local leaves = layout[2]
    if (kind ~= "row" and kind ~= "col") or #leaves ~= 2 or leaves[1][1] ~= "leaf" or leaves[2][1] ~= "leaf" then
      vim.notify("transpose splits only supports a simple two-window layout", vim.log.levels.INFO)
      return
    end

    local current = vim.api.nvim_get_current_win()
    local first = leaves[1][2]
    local second = leaves[2][2]

    if kind == "row" then
      vim.cmd.wincmd(current == first and "K" or "J")
      return
    end

    vim.cmd.wincmd(current == first and "H" or "L")
  end

  function window.swap_with(direction)
    local current = vim.api.nvim_get_current_win()
    local target = adjacent_window(direction)
    if target == nil then
      vim.notify(("no split to swap with on the %s"):format(direction), vim.log.levels.INFO)
      return
    end

    swap_window_state(current, target)
    vim.api.nvim_set_current_win(target)
  end

  function window.new_scratch_split(direction)
    local split_command = direction == "vertical" and "botright vsplit" or "botright split"
    vim.cmd(split_command)
    vim.cmd.enew()

    local current_buffer = vim.api.nvim_get_current_buf()
    vim.b[current_buffer].helix_scratch_split = true
    vim.bo[current_buffer].bufhidden = "wipe"
    vim.bo[current_buffer].buflisted = true
    vim.bo[current_buffer].swapfile = false
    vim.bo[current_buffer].modifiable = true
  end

  function window.toggle_focus()
    local current_tab = vim.api.nvim_get_current_tabpage()

    if focus_state then
      local focus_tab_valid = vim.api.nvim_tabpage_is_valid(focus_state.focus_tab)
      if focus_tab_valid and current_tab == focus_state.focus_tab then
        focus_state = nil
        vim.cmd.tabclose()
        return
      end

      focus_state = nil
    end

    if #current_tab_windows() <= 1 then
      vim.notify("current tab is already focused", vim.log.levels.INFO)
      return
    end

    focus_state = {}
    vim.cmd("tab split")
    focus_state.focus_tab = vim.api.nvim_get_current_tabpage()
  end

  return window
end

return M
