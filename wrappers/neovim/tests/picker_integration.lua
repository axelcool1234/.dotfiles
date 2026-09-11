local helix = require("axelcool1234.helix")
local pickers = require("axelcool1234.pickers")
local state = require("axelcool1234.helix.state")

local function assert_equal(actual, expected, label)
  if not vim.deep_equal(actual, expected) then
    error(label .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual))
  end
end

vim.cmd("enew!")
vim.bo.filetype = "lua"
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "local origin = target",
  "xxx target z",
  "yyy target z",
})
vim.api.nvim_win_set_cursor(0, { 1, 15 })

local buffer = vim.api.nvim_get_current_buf()
local original_references = vim.lsp.buf.references
local request_opts
vim.lsp.buf.references = function(_, opts)
  request_opts = opts
end

local ok, err = xpcall(function()
  pickers.references_picker()
  assert(request_opts and request_opts.on_list, "gr should install an LSP list callback")

  request_opts.on_list({
    title = "References",
    items = {
      { bufnr = buffer, lnum = 2, col = 5, end_lnum = 2, end_col = 11, text = "xxx target z" },
      { bufnr = buffer, lnum = 3, col = 5, end_lnum = 3, end_col = 11, text = "yyy target z" },
    },
  })

  local action_state = require("telescope.actions.state")
  assert(vim.wait(2000, function()
    return action_state.get_selected_entry() ~= nil
  end, 10), "the references picker should populate its results")
  local enter = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
  vim.api.nvim_feedkeys(enter, "xt", false)
  assert(vim.wait(2000, function()
    return vim.api.nvim_get_current_buf() == buffer and vim.api.nvim_win_get_cursor(0)[1] == 2
  end, 10), "the references picker should select its first result")
  vim.wait(50)

  local entry = helix.primary_selection_entry()
  assert_equal(state.get_entry_text(entry), "target", "gr should retain the complete reference range")
  assert_equal(entry.cursor_pos, { 2, 5 }, "the Helix selection cursor should be at the reference start")
  assert_equal(vim.api.nvim_win_get_cursor(0), { 2, 4 }, "the real cursor should be on the selection head")
end, debug.traceback)

vim.lsp.buf.references = original_references
if not ok then
  error(err)
end

print("picker-integration-tests-ok")
