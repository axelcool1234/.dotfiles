return {
  cmd = { 'typescript-language-server', '--stdio' },
  filetypes = {
    'javascript',
    'javascriptreact',
    'javascript.jsx',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
  },
  root_markers = {
    'tsconfig.json',
    'jsconfig.json',
    'package.json',
    'deno.json',
    'deno.jsonc',
    '.git',
  },
  init_options = {
    hostInfo = 'neovim',
  },
}
