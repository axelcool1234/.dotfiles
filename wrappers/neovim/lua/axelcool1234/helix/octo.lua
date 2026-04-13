local helix = require("axelcool1234.helix")

local M = {}

local function octo_diff_buffer(bufnr)
  local ok, _ = pcall(vim.api.nvim_buf_get_var, bufnr, "octo_diff_props")
  return ok
end

local function primary_selection_line_range()
  local entries = helix.current_selection_entries()
  local entry = helix.primary_selection_entry()
  if not entry then
    return nil
  end

  if #entries > 1 then
    vim.notify("Octo review comments use only the primary Helix selection", vim.log.levels.INFO)
  end

  return entry.start_pos[1], entry.end_pos[1]
end

local function run_ranged_octo(action)
  if not octo_diff_buffer(vim.api.nvim_get_current_buf()) then
    vim.notify("Octo Helix comment commands only work in Octo review diff buffers", vim.log.levels.WARN)
    return
  end

  local line1, line2 = primary_selection_line_range()
  if not line1 or not line2 then
    vim.notify("No Helix selection available for Octo comment", vim.log.levels.WARN)
    return
  end

  vim.cmd(("%d,%d Octo comment %s"):format(line1, line2, action))
end

function M.add_comment_from_primary_selection()
  run_ranged_octo("add")
end

function M.add_suggestion_from_primary_selection()
  run_ranged_octo("suggest")
end

function M.setup()
  vim.api.nvim_create_user_command("OctoHelixCommentAdd", function()
    M.add_comment_from_primary_selection()
  end, { desc = "Add an Octo review comment from the Helix primary selection" })

  vim.api.nvim_create_user_command("OctoHelixCommentSuggest", function()
    M.add_suggestion_from_primary_selection()
  end, { desc = "Add an Octo review suggestion from the Helix primary selection" })
end

return M
