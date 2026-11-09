require('gitsigns').setup({
  diff_opts = {
    -- Helix selects whole diff hunks. Neovim's inherited linematch setting
    -- can split one replacement into separate addition and change hunks.
    linematch = 0,
  },
})
