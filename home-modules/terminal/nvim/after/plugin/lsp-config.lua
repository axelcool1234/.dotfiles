-- Load required modules
local lspconfig = require('lspconfig')

-- Set up lspconfig
local capabilities = require('cmp_nvim_lsp').default_capabilities()
local on_attach = function(client, bufnr)
	vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

    -- if client.server_capabilities.inlayHintProvider then
    --     vim.g.inlay_hints_visible = true
    --     vim.lsp.inlay_hint(bufnr, true)
    -- end
end

-- Configure language servers
-- Nix
lspconfig.nil_ls.setup {
  autostart = true,
  capabilities = capabilities,
  on_attach = on_attach,
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
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- TypeScript/JavaScript
lspconfig.tsserver.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- Rust
lspconfig.rust_analyzer.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- C/C++
lspconfig.clangd.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- Go
lspconfig.gopls.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- Ruby
lspconfig.solargraph.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- Java
lspconfig.jdtls.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- PHP
lspconfig.intelephense.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- Lua
lspconfig.lua_ls.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- HTML, CSS, JavaScript (web development)
lspconfig.html.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}
lspconfig.cssls.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- Vue.js
lspconfig.volar.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- C#
lspconfig.omnisharp.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- Kotlin
lspconfig.kotlin_language_server.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}

-- Swift
lspconfig.sourcekit.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
}
