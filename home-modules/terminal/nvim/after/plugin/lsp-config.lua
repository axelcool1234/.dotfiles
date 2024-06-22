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
  document_highlight = { enabled = false }
}

-- Python
lspconfig.pyright.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- TypeScript/JavaScript
lspconfig.tsserver.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- Rust
lspconfig.rust_analyzer.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- C/C++
lspconfig.clangd.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- Go
lspconfig.gopls.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- Ruby
lspconfig.solargraph.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- Java
lspconfig.jdtls.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- PHP
lspconfig.intelephense.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- Lua
lspconfig.lua_ls.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- HTML, CSS, JavaScript (web development)
lspconfig.html.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}
lspconfig.cssls.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- Vue.js
lspconfig.volar.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- C#
lspconfig.omnisharp.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- Kotlin
lspconfig.kotlin_language_server.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}

-- Swift
lspconfig.sourcekit.setup {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    hint = true,
  },
  document_highlight = { enabled = false }
}
