local capabilities = require('cmp_nvim_lsp').default_capabilities()

vim.lsp.config('*', {
  capabilities = capabilities,
})

local function enable(server_name, config)
  vim.lsp.config(server_name, config or {})
  vim.lsp.enable(server_name)
end

-- Dafny
enable('dafny', {
  filetypes = { 'dfy', 'dafny' },
  root_markers = { { 'dafny.toml', 'Dafny.toml' }, '.git' },
})

-- Nix
enable('nil_ls', {
  cmd = { 'nil' },
  settings = {
    ['nil'] = {
      testSetting = 42,
      formatting = {
        command = { 'nixpkgs-fmt' },
      },
    },
  },
})

-- TableGen
enable('tblgen_lsp_server', {
  cmd = {
    'tblgen-lsp-server',
    '--tablegen-compilation-database=/home/axelcool1234/.dotfiles/misc/envs/llvm/build/tablegen_compile_commands.yml',
  },
  settings = {
    hint = true,
  },
})

-- Python
enable('pyright', {
  settings = {
    hint = true,
  },
})

-- LaTeX (texlab)
enable('texlab', {
  settings = {
    texlab = {
      -- build = {
      --   onSave = false,
      --   forwardSearchAfter = false,
      --   -- executable = 'tectonic',
      --   -- args = { '-X', 'compile', '%f', '--synctex', '-Zshell-escape', '--keep-logs', '--keep-intermediates' },
      --   executable = 'latexmk',
      --   args = { '-pdf', '-interaction=nonstopmode', '-synctex=1', '%f' },
      -- },
      -- forwardSearch = {
      --   executable = 'zathura',
      --   args = { '--synctex-forward', '%l:1:%f', '%p' },
      -- },
      chktex = {
        onEdit = true,
      },
      auxDirectory = '.',
      bibtexFormatter = 'texlab',
      diagnosticsDelay = 300,
      formatterLineLength = 80,
      latexFormatter = 'latexindent',
      latexindent = {
        modifyLineBreaks = true,
      },
    },
  },
})

-- Typst
enable('tinymist', {
  settings = {
    hint = true,
  },
})

-- Haskell
enable('hls', {
  settings = {
    hint = true,
  },
})

-- Rust (using rustaceanvim instead!)
-- enable('rust_analyzer', {
--   settings = {
--     hint = true,
--     ['rust-analyzer'] = {
--       cargo = {
--         allFeatures = true,
--       },
--       checkOnSave = {
--         command = 'clippy',
--       },
--     },
--   },
-- })

-- C/C++
enable('clangd', {
  settings = {
    hint = true,
  },
})

-- Go
enable('gopls', {
  settings = {
    hint = true,
  },
})

-- OCaml
enable('ocamllsp', {
  settings = {
    hint = true,
  },
})

-- Ruby
enable('solargraph', {
  settings = {
    hint = true,
  },
})

-- Java
enable('jdtls', {
  settings = {
    hint = true,
  },
})

-- PHP
enable('intelephense', {
  settings = {
    hint = true,
  },
})

-- Lua
enable('lua_ls', {
  settings = {
    hint = true,
  },
})

-- HTML, CSS, JavaScript (web development)
enable('html', {
  settings = {
    hint = true,
  },
})

enable('cssls', {
  settings = {
    hint = true,
  },
})

-- Vue.js
enable('volar', {
  settings = {
    hint = true,
  },
})

-- C#
enable('omnisharp', {
  settings = {
    hint = true,
  },
})

-- Kotlin
enable('kotlin_language_server', {
  settings = {
    hint = true,
  },
})

-- Swift
-- enable('sourcekit', {
--   settings = {
--     hint = true,
--   },
-- })
