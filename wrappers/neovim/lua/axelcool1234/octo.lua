local M = {}

local function matches_context(context, kind)
  if context == nil then
    return false
  end

  if type(context) == "table" then
    return vim.tbl_contains(context, kind)
  end

  return context == kind
end

local function add_wk_entry(entries, key, bufnr, extra)
  extra = extra or {}
  local wk_entry = { key.bind }
  for field, value in pairs(extra) do
    wk_entry[field] = value
  end
  wk_entry.mode = key.mode
  wk_entry.buffer = bufnr
  entries[#entries + 1] = wk_entry
end

local function refresh_which_key(bufnr)
  local ok, wk_buf = pcall(require, "which-key.buf")
  if ok then
    wk_buf.clear({ buf = bufnr })
  end
end

local function octo_buffer(bufnr)
  local buffers = rawget(_G, "octo_buffers")
  return type(buffers) == "table" and buffers[bufnr] or nil
end

local function contextual_kind(utils, bufnr)
  if utils.in_diff_window(bufnr) then
    return "octo.review_diff"
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if vim.startswith(vim.fn.fnamemodify(name, ":t"), "OctoChangedFiles-") then
    return "octo.file_panel"
  end

  local buffer = octo_buffer(bufnr)
  if not buffer then
    return nil
  end

  if buffer.isReviewThread and buffer:isReviewThread() then
    return "octo.review_thread"
  end
  if buffer.isPullRequest and buffer:isPullRequest() then
    return "octo.pull_request"
  end
  if buffer.isIssue and buffer:isIssue() then
    return "octo.issue"
  end
  if buffer.isDiscussion and buffer:isDiscussion() then
    return "octo.discussion"
  end

  return nil
end

local function apply_contextual_keys(keys, bufnr, kind)
  local wk = require("which-key")
  local seen = {}
  local wk_entries = {}

  for _, key in ipairs(keys) do
    if matches_context(key.context, kind) then
      local modes = type(key.mode) == "table" and key.mode or { key.mode }
      for _, mode in ipairs(modes) do
        local signature = table.concat({ mode, key.bind }, "\0")
        if not seen[signature] then
          if key.action ~= nil and not key.group then
            local final_opts = vim.tbl_extend("force", { silent = true }, key.opts, { buffer = bufnr, desc = key.label })
            vim.keymap.set(mode, key.bind, key.action, final_opts)
          end

          if key.group then
            add_wk_entry(wk_entries, key, bufnr, { group = key.label, expand = key.expand })
          elseif key.hidden then
            add_wk_entry(wk_entries, key, bufnr, { hidden = true })
          else
            add_wk_entry(wk_entries, key, bufnr, { desc = key.label })
          end

          seen[signature] = true
        end
      end
    end
  end

  if #wk_entries > 0 then
    wk.add(wk_entries)
  end
end

local function thread_lines(bufnr)
  local namespace = require("octo.constants").OCTO_THREAD_NS
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
  local lines = {}

  for _, mark in ipairs(marks) do
    lines[#lines + 1] = mark[2] + 1
  end

  table.sort(lines)
  return lines
end

local function jump_thread(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = thread_lines(bufnr)
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local target = nil

  if direction > 0 then
    for _, line in ipairs(lines) do
      if line > current_line then
        target = line
        break
      end
    end
  else
    for index = #lines, 1, -1 do
      local line = lines[index]
      if line < current_line then
        target = line
        break
      end
    end
  end

  if target then
    vim.api.nvim_win_set_cursor(0, { target, 0 })
  end
end

function M.goto_next_thread()
  jump_thread(1)
end

function M.goto_previous_thread()
  jump_thread(-1)
end

function M.search_current_repo()
  require("octo.utils").create_base_search_command({
    include_current_repo = true,
  })
end

function M.setup_buffer_mappings(keys)
  local utils = require("octo.utils")

  local function apply(bufnr, kind)
    if vim.b[bufnr].axelcool1234_octo_mapping_kind == kind then
      return
    end

    apply_contextual_keys(keys, bufnr, kind)

    vim.b[bufnr].axelcool1234_octo_mapping_kind = kind
    refresh_which_key(bufnr)
  end

  local function schedule_apply(bufnr, attempt)
    attempt = attempt or 1
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local kind = contextual_kind(utils, bufnr)
    if kind then
      apply(bufnr, kind)
      return
    end

    if attempt < 20 then
      vim.defer_fn(function()
        schedule_apply(bufnr, attempt + 1)
      end, 50)
    end
  end

  local group = vim.api.nvim_create_augroup("axelcool1234-octo-buffer-maps", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function(args)
      schedule_apply(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "octo",
    callback = function(args)
      schedule_apply(args.buf)
    end,
  })
end

return M
