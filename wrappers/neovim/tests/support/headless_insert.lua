local position = require("axelcool1234.helix.position")

local M = {}

function M.finish()
  vim.api.nvim_exec_autocmds("InsertLeave", {
    buffer = vim.api.nvim_get_current_buf(),
    modeline = false,
  })
end

-- :startinsert cannot enter Insert mode while a headless Lua chunk is still
-- running. Reproduce the observable state after typing and pressing Escape.
function M.simulate(text)
  assert(not text:find("\n", 1, true), "the insert simulation accepts one line")
  local width = position.grapheme_count(text)
  assert(width > 0, "the insert simulation requires nonempty text")
  local buffer = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local col = position.grapheme_col_from_byte_col0(position.line_text(buffer, cursor[1]), cursor[2])
  vim.api.nvim_buf_set_text(buffer, cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2], { text })
  local updated = position.line_text(buffer, cursor[1])
  local escape_col = position.byte_col0_from_grapheme_col(updated, col + width - 1)
  vim.api.nvim_win_set_cursor(0, { cursor[1], escape_col })
  M.finish()
end

return M
