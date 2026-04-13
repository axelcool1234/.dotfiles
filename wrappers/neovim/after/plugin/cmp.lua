local cmp = require('cmp')
local luasnip = require('luasnip')

require('luasnip.loaders.from_vscode').lazy_load()

-- Global insert-mode completion. Keep the first group focused on semantic or
-- structured candidates, and push plain text sources into the fallback group.
local global_sources = cmp.config.sources({
  { name = 'nvim_lsp' },
  { name = 'nvim_lsp_signature_help' },
  { name = 'luasnip' },
  { name = 'path' },
  { name = 'nvim_lua' },
  { name = 'calc' },
  { name = 'emoji' },
  { name = 'treesitter' },
}, {
  { name = 'buffer' },
  { name = 'rg', keyword_length = 5 },
})

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  preselect = cmp.PreselectMode.None,
  completion = {
    completeopt = 'menu,menuone,noinsert',
  },
  sources = global_sources,
})

-- Commit messages benefit from git-aware candidates such as commits, issues,
-- and mentions, with buffer words as a fallback.
cmp.setup.filetype('gitcommit', {
  sources = cmp.config.sources({
    { name = 'git' },
  }, {
    { name = 'buffer' },
  }),
})

require('cmp_git').setup()

-- Shell-like files and .env files often need environment-variable names more
-- than LSP items, so use a focused source list there.
cmp.setup.filetype({ 'sh', 'bash', 'zsh', 'dotenv' }, {
  sources = cmp.config.sources({
    { name = 'path' },
    {
      name = 'dotenv',
      option = {
        load_shell = false,
      },
    },
  }, {
    { name = 'buffer' },
  }),
})

-- TODO: When DAP support is added to this config, enable cmp-dap for
-- `dap-repl`, `dapui_watches`, and related debug buffers.

-- Search mode should prefer nearby buffer text, with history as a fallback.
cmp.setup.cmdline({ '/', '?' }, {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'buffer' },
  }, {
    { name = 'cmdline_history' },
  }),
})

-- Ex commands should prefer real commands and paths, while still letting you
-- recall past command-line entries when useful.
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' },
  }, {
    { name = 'cmdline' },
    { name = 'cmdline_history' },
  }),
  matching = {
    disallow_symbol_nonprefix_matching = false,
  },
})
