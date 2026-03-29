vim.opt.guicursor = ""

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true 

-- vim.opt.swapfile = false
-- vim.opt.backup = false
-- vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
-- vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

_G.axelcool1234_make_bufferline_highlights = function()
  local colors = _G.axelcool1234_noctalia_base16
  if colors == nil then
    return {}
  end

  return {
    fill = {
      bg = colors.base00,
    },
    background = {
      fg = colors.base03,
      bg = colors.base00,
    },
    buffer_visible = {
      fg = colors.base05,
      bg = colors.base01,
    },
    buffer_selected = {
      fg = colors.base05,
      bg = colors.base00,
      bold = true,
      italic = false,
    },
    separator = {
      fg = colors.base00,
      bg = colors.base00,
    },
    separator_visible = {
      fg = colors.base01,
      bg = colors.base01,
    },
    separator_selected = {
      fg = colors.base00,
      bg = colors.base00,
    },
    indicator_selected = {
      fg = colors.base0D,
      bg = colors.base00,
    },
    modified = {
      fg = colors.base09,
      bg = colors.base00,
    },
    modified_visible = {
      fg = colors.base09,
      bg = colors.base01,
    },
    modified_selected = {
      fg = colors.base0B,
      bg = colors.base00,
    },
    close_button = {
      fg = colors.base03,
      bg = colors.base00,
    },
    close_button_visible = {
      fg = colors.base03,
      bg = colors.base01,
    },
    close_button_selected = {
      fg = colors.base08,
      bg = colors.base00,
    },
    duplicate_selected = {
      fg = colors.base04,
      bg = colors.base00,
      italic = true,
    },
    duplicate_visible = {
      fg = colors.base04,
      bg = colors.base01,
      italic = true,
    },
    duplicate = {
      fg = colors.base03,
      bg = colors.base00,
      italic = true,
    },
    tab_selected = {
      fg = colors.base05,
      bg = colors.base00,
      bold = true,
    },
    tab = {
      fg = colors.base03,
      bg = colors.base00,
    },
    tab_close = {
      fg = colors.base08,
      bg = colors.base00,
    },
  }
end

_G.axelcool1234_refresh_bufferline = function()
  local ok_bufferline, bufferline = pcall(require, "bufferline")
  if not ok_bufferline then
    return false
  end

  local ok_config, bufferline_config = pcall(require, "bufferline.config")
  local ok_highlights, bufferline_highlights = pcall(require, "bufferline.highlights")
  local ok_ui, bufferline_ui = pcall(require, "bufferline.ui")

  if ok_config and bufferline_config.get() ~= nil then
    -- Mirror bufferline's own ColorScheme autocmd: reset cached icon highlights,
    -- rebuild highlight groups from the current colorscheme, then refresh the UI.
    if ok_highlights then
      bufferline_highlights.reset_icon_hl_cache()
      bufferline_highlights.set_all(bufferline_config.update_highlights())
    else
      bufferline_config.update_highlights()
    end

    if ok_ui then
      bufferline_ui.refresh()
    end
  else
    bufferline.setup {
      highlights = _G.axelcool1234_make_bufferline_highlights(),
    }
  end

  vim.cmd.redrawtabline()
  return true
end

if vim.env.NVIM_ENABLE_NOCTALIA_THEME == "1" then
  local generated_theme_path = vim.fn.expand("~/.cache/noctalia/nvim-base16.lua")
  local theme_signal = nil

  local function apply_noctalia_theme()
    local ok_base16, base16 = pcall(require, "base16-colorscheme")
    if not ok_base16 then
      return false
    end

    local chunk = loadfile(generated_theme_path)
    if chunk == nil then
      return false
    end

    local ok_theme, theme = pcall(chunk)
    if not ok_theme or type(theme) ~= "table" then
      return false
    end

    _G.axelcool1234_noctalia_base16 = theme

    base16.setup(theme)

    -- `base16-colorscheme`.setup() updates highlights directly but does not emit
    -- a normal `:colorscheme` transition. Many UI plugins, including lualine
    -- and bufferline, listen for the ColorScheme autocmd to rebuild their own
    -- derived highlights, so fire it manually here.
    vim.api.nvim_exec_autocmds('ColorScheme', {
      modeline = false,
      pattern = vim.g.colors_name or '*',
    })

    if _G.axelcool1234_refresh_bufferline ~= nil then
      vim.schedule(function()
        _G.axelcool1234_refresh_bufferline()
      end)
    end

    return true
  end

  apply_noctalia_theme()

  theme_signal = vim.uv.new_signal()
  if theme_signal ~= nil then
    _G.axelcool1234_noctalia_theme_signal = theme_signal

    theme_signal:start("sigusr1", vim.schedule_wrap(function()
      apply_noctalia_theme()
    end))
  end
end

vim.opt.scrolloff = 8
-- vim.opt.signcolumn = "yes"

vim.opt.updatetime = 50

-- vim.opt.colorcolumn = "80"

vim.opt.grepprg = "rg --vimgrep --smart-case --hidden"
vim.opt.grepformat = "%f:%l:%c:%m"

-- Vimtex
-- Disable opening the quickfix window for warnings
-- vim.g.vimtex_quickfix_mode = 0

-- Set Zathura as the viewer
vim.g.vimtex_view_method = 'zathura'

-- Configure forward search
vim.g.vimtex_view_general_options = '--synctex-forward @line:@col:@pdf %p'

local lsp_attach_group = vim.api.nvim_create_augroup('axelcool1234-lsp-attach', { clear = true })

local function toggle_inlay_hints(bufnr)
  local filter = { bufnr = bufnr }
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
end

vim.api.nvim_create_autocmd('LspAttach', {
  group = lsp_attach_group,
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufnr = args.buf

    if not client then
      return
    end

    vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

    if client:supports_method('textDocument/inlayHint') then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      vim.keymap.set('n', '<leader>i', function()
        toggle_inlay_hints(bufnr)
      end, { buffer = bufnr, desc = 'Toggle inlay hints', silent = true })
    end
  end,
})

-- Rustaceanvim
vim.g.rustaceanvim = {
  -- tools = {
  --   test_executor = 'background',
  -- },
  server = {
    default_settings = {
      -- rust-analyzer language server configuration
      ['rust-analyzer'] = {
        inlayHints = {
          -- maxLength = 25,
          bindingModeHints = {
            enable = true
          },
          closureCaptureHints = {
            enable = true
          },
          closureReturnTypeHints = {
            enable = "always"
          },
          closureStyle = "impl_fn",
          -- closureStyle = "rust",
          discriminantHints = {
            enable = "always"
          },
          expressionAdjustmentHints = {
            enable = "always"
          },
          genericParameterHints = {
            lifetime = {
              enable = true
            },
            type = {
              enable = true
            },
          },
          implicitDrops = {
            enable = true
          },
          lifetimeElisionHints = {
            enable = "always",
            -- useParameterNames = true
          },
          rangeExclusiveHints = {
            enable = true
          },
          tests = true,
        },
      },
    },
  },
}

-- RustFmt
vim.g.rustfmt_autosave = 1

-- CPP
vim.api.nvim_create_autocmd("FileType", {
    pattern = "cpp",
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.expandtab = true
    end,
})
