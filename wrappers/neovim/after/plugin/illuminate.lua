require('illuminate').configure({
  delay = 200,
  -- Use a cheaper provider set in large files instead of disabling the plugin.
  large_file_cutoff = 2000,
  large_file_overrides = {
    providers = { 'lsp' },
  },
})
