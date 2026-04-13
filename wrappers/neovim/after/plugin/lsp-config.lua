local capabilities = require('cmp_nvim_lsp').default_capabilities()

vim.lsp.config('*', {
  capabilities = capabilities,
})

vim.lsp.enable('nil_ls')
vim.lsp.enable('clangd')
vim.lsp.enable('lua_ls')
