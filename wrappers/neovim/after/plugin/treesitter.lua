-- [[ Configure Treesitter ]]
-- See `:help nvim-treesitter`

local treesitter_group = vim.api.nvim_create_augroup('axelcool1234-treesitter', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
  group = treesitter_group,
  callback = function(args)
    -- Let lean.nvim drive Lean highlighting while keeping the parser packaged
    -- for Tree-sitter motions/textobjects.
    if vim.bo[args.buf].filetype == 'lean' then
      return
    end

    pcall(vim.treesitter.start, args.buf)
  end,
})
