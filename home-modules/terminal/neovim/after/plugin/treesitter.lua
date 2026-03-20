-- [[ Configure Treesitter ]]
-- See `:help nvim-treesitter`

local treesitter_group = vim.api.nvim_create_augroup('axelcool1234-treesitter', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
  group = treesitter_group,
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})
