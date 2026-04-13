{
  hostVars,
  wlib,
  lib,
  pkgs,
  selfPkgs,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktop-shell == "noctalia-shell";
in
{
  imports = [ wlib.wrapperModules.neovim ];

  # Use this directory itself as the wrapped Neovim config directory.
  settings.config_directory = ./.;

  # Plugin groups. Keep wrapper-specific bootstraps close to the plugin that
  # needs them, and keep general editor behavior in the Lua config directory.
  specs =
    {
      # Startup foundations that other plugins or config depend on.
      core = with pkgs.vimPlugins; [
        plenary-nvim # several plugins need this
        {
          name = "nvim-treesitter";
          data = nvim-treesitter;
          before = [ "INIT_MAIN" ];
          # nvim-treesitter ships its queries under a nested `runtime/` tree,
          # so surface that subtree before the main config runs.
          config = /* lua */ ''
            local nix_info = require(vim.g.nix_info_plugin_name)
            local plugin = nix_info(nil, "plugins", "start", "nvim-treesitter")
            if plugin then
              vim.opt.runtimepath:append(plugin .. "/runtime")
            end
          '';
        }
        nvim-treesitter-textobjects # TODO: wire treesitter motions into Helix-style remaps
        mini-icons # (gives icons for which-key)
      ];

      # Interactive pickers and fuzzy navigation.
      navigation = with pkgs.vimPlugins; [
        telescope-nvim
        telescope-fzf-native-nvim
      ];

      # Diagnostics and non-LSP lint integrations.
      lsp = with pkgs.vimPlugins; [
        nvim-lint
      ];

      # Completion engine plus its active sources/snippet bridge.
      completion = with pkgs.vimPlugins; [
        nvim-cmp                    # Completion menu engine. Shows and ranks suggestions from all sources below.
        cmp-nvim-lsp                # Feed language-server completion items into nvim-cmp.
        cmp-nvim-lsp-signature-help # Feed active function signature/help items into nvim-cmp.
        cmp-nvim-lua                # Feed Neovim's Lua API/help items (for `vim.*` etc.) into nvim-cmp.
        cmp_luasnip                 # Feed snippet triggers from LuaSnip into nvim-cmp.
        cmp-buffer                  # Feed words from the current buffer into nvim-cmp.
        cmp-path                    # Feed filesystem paths into nvim-cmp.
        cmp-cmdline                 # Feed `:` command-line completions into nvim-cmp.
        cmp-cmdline-history         # Feed previous `:`, `/`, and `?` history entries into nvim-cmp.
        cmp-calc                    # Feed inline calculator results into nvim-cmp.
        cmp-emoji                   # Feed emoji names into nvim-cmp.
        cmp-rg                      # Feed ripgrep-backed project text matches into nvim-cmp.
        cmp-treesitter              # Feed syntax-node text from Tree-sitter into nvim-cmp.
        cmp-git                     # Feed git commit/issues/mentions completions into commit buffers.
        cmp-dotenv                  # Feed `.env*` variables into shell-ish buffers.
        cmp-dap                     # TODO: Enable this once DAP support lands in the Neovim config.
        luasnip                     # Snippet engine. Expands snippet bodies and lets you jump through placeholders.
        friendly-snippets           # Large VS Code-format snippet collection loaded by LuaSnip.
      ];

      # UI chrome and status surfaces that should be present on startup.
      ui = with pkgs.vimPlugins; [
        which-key-nvim
        gitsigns-nvim
        lualine-nvim
        lualine-lsp-progress
        # git-prompt-string-lualine-nvim
        bufferline-nvim
        indent-blankline-nvim
      ];

      # Editing helpers that operate on the current buffer contents.
      editing = with pkgs.vimPlugins; [
        todo-comments-nvim
        vim-illuminate
        vim-sandwich
      ];

      # Language-specific plugins that are not just plain LSP clients.
      languages = with pkgs.vimPlugins; [
        vimtex
        lean-nvim
      ];

      # Non-essential integrations.
      fun = with pkgs.vimPlugins; [
        presence-nvim
      ];

      # Parsers are packaged separately from the main treesitter plugin.
      treesitter-grammars = lib.attrVals [
        # Core editor and shell config languages.
        "bash"
        "fish"
        "kitty"
        "lua"
        "nix"
        "vim"
        "vimdoc"
        "ssh_config"
        "editorconfig"

        # Documentation, markup, and prose.
        "doxygen"
        "html"
        "latex"
        "markdown"
        "markdown_inline"
        "typst"
        "xml"

        # Structured data and application config formats.
        "csv"
        "http"
        "json"
        "toml"
        "yaml"
        "zathurarc"

        # Styling, layout, and graph-like formats.
        "css"
        "dot"
        "scss"

        # Version-control and patch editing.
        "diff"
        "git_config"
        "git_rebase"
        "gitattributes"
        "gitcommit"
        "gitignore"

        # Build systems, containers, and project tooling.
        "cmake"
        "dockerfile"
        "make"
        "ninja"

        # Programming languages and compiler/toolchain formats.
        "awk"
        "cpp"
        "c"
        "cuda"
        "jq"
        "llvm"
        "mlir"
        "python"
        "rust"
        "tablegen"

        # Useful for Tree-sitter-powered query editing and regex-aware motions.
        "query"
        "regex"
      ] pkgs.vimPlugins.nvim-treesitter-parsers ++ [
        # lean.nvim ships Lean queries, but the parser itself is packaged here.
        selfPkgs.treesitter-grammar-lean
      ];
    }
    // lib.optionalAttrs useNoctaliaTheme {
      # Noctalia-only theme bootstrap and live palette reload hook.
      theme = with pkgs.vimPlugins; [
        {
          name = "noctalia-theme";
          data = base16-nvim;
          before = [ "INIT_MAIN" ];
          config = /* lua */ ''
            local uv = vim.uv or vim.loop
            local palette_path = vim.fn.expand("~/.cache/noctalia/nvim-base16.lua")
            local signal = nil

            local function apply_noctalia_palette()
              if not uv.fs_stat(palette_path) then
                return
              end

              local palette_ok, palette = pcall(dofile, palette_path)
              if not palette_ok then
                vim.notify(
                  ("Noctalia palette could not be loaded from %s: %s"):format(palette_path, palette),
                  vim.log.levels.WARN
                )
                return
              end

              local base16_ok, base16 = pcall(require, "base16-colorscheme")
              if not base16_ok then
                vim.notify(
                  ("base16-colorscheme is unavailable: %s"):format(base16),
                  vim.log.levels.ERROR
                )
                return
              end

              base16.setup(palette)

              vim.api.nvim_exec_autocmds("ColorScheme", {
                modeline = false,
                pattern = "noctalia-base16",
              })
              vim.api.nvim_exec_autocmds("User", {
                modeline = false,
                pattern = "NoctaliaThemeReloaded",
              })
            end

            apply_noctalia_palette()

            signal = uv.new_signal()
            if signal then
              signal:start("sigusr1", vim.schedule_wrap(apply_noctalia_palette))

              vim.api.nvim_create_autocmd("VimLeavePre", {
                callback = function()
                  if signal:is_closing() then
                    return
                  end

                  signal:stop()
                  signal:close()
                end,
              })
            end
          '';
        }
      ];
    };

  # Common tools this config shells out to.
  extraPackages = [
    pkgs.fzf
    pkgs.fd
    pkgs.ripgrep
    selfPkgs.lazygit
  ];
}
