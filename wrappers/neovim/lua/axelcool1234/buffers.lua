local M = {}

local function listed_file_buffers(excluded)
  local alternate = vim.fn.bufnr("#")
  local buffers = {}

  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    local bufnr = info.bufnr
    if bufnr ~= excluded
      and vim.api.nvim_buf_is_valid(bufnr)
      and vim.bo[bufnr].buftype == ""
      and vim.b[bufnr].helix_scratch_split ~= true then
      buffers[#buffers + 1] = bufnr
    end
  end

  table.sort(buffers, function(left, right)
    if left == alternate then
      return true
    end
    if right == alternate then
      return false
    end
    return left < right
  end)

  return buffers
end

local function first_replacement_buffer(excluded)
  return listed_file_buffers(excluded)[1]
end

local function is_helix_scratch_split(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr) and vim.b[bufnr].helix_scratch_split == true
end

local function normal_window_count()
  local count = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
      count = count + 1
    end
  end

  return count
end

function M.has_listed_file_buffer(excluded)
  return first_replacement_buffer(excluded) ~= nil
end

local function jump_to_non_fixed_window()
  if not vim.wo.winfixbuf then
    return true
  end

  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= current and vim.api.nvim_win_is_valid(win) and not vim.wo[win].winfixbuf then
      vim.api.nvim_set_current_win(win)
      return true
    end
  end

  return false
end

local function ensure_edit_window()
  if jump_to_non_fixed_window() then
    return true
  end

  vim.cmd("vsplit")
  vim.wo.winfixbuf = false

  local replacement = first_replacement_buffer(vim.api.nvim_get_current_buf())
  if replacement then
    vim.api.nvim_set_current_buf(replacement)
  else
    vim.cmd("enew")
  end

  return true
end

M.ensure_edit_window = ensure_edit_window

local function run_bufferline_cycle(command)
  ensure_edit_window()
  vim.cmd(command)
end

function M.cycle_next()
  run_bufferline_cycle("BufferLineCycleNext")
end

function M.cycle_prev()
  run_bufferline_cycle("BufferLineCyclePrev")
end

function M.close_current_buffer(force)
  local target = vim.api.nvim_get_current_buf()
  local command = force and "bdelete!" or "bdelete"

  if is_helix_scratch_split(target) and normal_window_count() > 1 then
    if force then
      vim.cmd("close!")
      return
    end

    if vim.bo[target].modified then
      vim.cmd(command)
      return
    end

    vim.cmd("close")
    return
  end

  if vim.bo[target].filetype == "leaninfo" then
    local ok, infoview = pcall(require, "lean.infoview")
    if ok then
      infoview.close()
      return
    end
  end

  if vim.bo[target].modified and not force then
    vim.cmd(command)
    return
  end

  local replacement = first_replacement_buffer(target)
  if replacement then
    vim.api.nvim_set_current_buf(replacement)
  else
    vim.cmd("enew")
  end

  vim.cmd(command .. " " .. target)
end

return M
