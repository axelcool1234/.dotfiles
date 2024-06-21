-- Load required modules
local lspconfig = require('lspconfig')

-- Set up lspconfig
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- Configure language servers
-- Nix
lspconfig.nil_ls.setup {
  autostart = true,
  capabilities = capabilities,
  cmd = { 'nil' },
  settings = {
    ['nil'] = {
      testSetting = 42,
      formatting = {
        command = { "nixpkgs-fmt" },
      },
    },
  },
}

-- Python
lspconfig.pyright.setup {
  capabilities = capabilities
}

-- TypeScript/JavaScript
lspconfig.tsserver.setup {
  capabilities = capabilities
}

-- Rust
lspconfig.rust_analyzer.setup {
  capabilities = capabilities
}

-- C/C++
lspconfig.clangd.setup {
  capabilities = capabilities
}

-- Go
lspconfig.gopls.setup {
  capabilities = capabilities
}

-- Ruby
lspconfig.solargraph.setup {
  capabilities = capabilities
}

-- Java
lspconfig.jdtls.setup {
  capabilities = capabilities
}

-- PHP
lspconfig.intelephense.setup {
  capabilities = capabilities
}

-- Lua
lspconfig.lua_ls.setup {
  capabilities = capabilities
}

-- HTML, CSS, JavaScript (web development)
lspconfig.html.setup {
  capabilities = capabilities
}
lspconfig.cssls.setup {
  capabilities = capabilities
}

-- Vue.js
lspconfig.volar.setup {
  capabilities = capabilities
}

-- C#
lspconfig.omnisharp.setup {
  capabilities = capabilities
}

-- Kotlin
lspconfig.kotlin_language_server.setup {
  capabilities = capabilities
}

-- Swift
lspconfig.sourcekit.setup {
  capabilities = capabilities
}
