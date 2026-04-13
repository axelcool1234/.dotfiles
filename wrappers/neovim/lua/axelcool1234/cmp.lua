local M = {}

local function feed(key)
  vim.api.nvim_feedkeys(vim.keycode(key), 'n', false)
end

function M.select_prev_item()
  require('cmp').select_prev_item()
end

function M.select_next_item()
  require('cmp').select_next_item()
end

function M.abort()
  require('cmp').abort()
end

function M.confirm()
  require('cmp').confirm({ select = true })
end

function M.jump_forward()
  local luasnip = require('luasnip')

  if luasnip.expand_or_locally_jumpable() then
    luasnip.expand_or_jump()
  else
    feed('<Tab>')
  end
end

function M.jump_backward()
  local luasnip = require('luasnip')

  if luasnip.locally_jumpable(-1) then
    luasnip.jump(-1)
  else
    feed('<S-Tab>')
  end
end

return M
