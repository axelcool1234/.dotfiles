{
  hostVars,
  wlib,
  lib,
  pkgs,
  selfPkgs,
  inputs,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktopShell == "noctalia";
  enableKittyScrollback = hostVars.terminal == "kitty";
  leanRepeatIssue = builtins.fromJSON (builtins.readFile inputs.lean-repeat-issue);
  leanRpcCancellationIssue = builtins.fromJSON (builtins.readFile inputs.lean-rpc-cancellation-issue);
  leanNvim =
    assert lib.assertMsg (leanRepeatIssue.state == "open") ''
      leanprover/lean4#14704 is no longer open. Re-test incomplete `repeat rw`
      with the project toolchain and review the lean.nvim infoview goal limit
      in wrappers/neovim/default.nix before removing or updating its issue guard.
    '';
    assert lib.assertMsg (leanRpcCancellationIssue.state == "open") ''
      Julian/lean.nvim#492 is no longer open. Review the local infoview RPC
      cancellation patch in wrappers/neovim/default.nix against upstream
      before removing or updating its issue guard.
    '';
    pkgs.vimPlugins.lean-nvim.overrideAttrs (old: {
      # Workaround for https://github.com/leanprover/lean4/issues/14704.
      #
      # Investigated on 2026-11-09 with Lean 4.34.0 and lean.nvim 2026.4.1.
      # While typing the Bool-function exercise, an unfinished `repeat rw`
      # repeatedly evaluated an incomplete tactic without changing its goal.
      # At the `rw` cursor position, getInteractiveGoals returned 1,025 entries
      # sharing ONE goal ID with maxHeartbeats = 5,000; at the default 200,000
      # budget it returned 41,096 entries. Hovering over `repeat` instead returned
      # one goal, which initially hid the reproduction from cursor-based tests.
      #
      # An isolated Neovim WITHOUT our Helix layer used 1.3 GiB RSS decoding that
      # response, 4.0 GiB after constructing interactive widgets, and 6.4 GiB
      # after rendering 287,671 lines and 3,123,297 element-position records.
      # The real session reached roughly 11 GiB. Finishing the proof did not
      # immediately release its old objects or return allocator pages: the live
      # Lua collector was paused at a 6.4 GiB heap below a 7.6 GiB GC threshold.
      # Even the isolated process retained 4.1 GiB RSS after discarding its
      # widgets and explicitly collecting garbage. RPC proxy accumulation was
      # a consequence of the oversized responses, not proof of a permanent leak.
      #
      # Related amplification mechanisms:
      # https://github.com/Julian/lean.nvim/issues/442 -- redundant goal requests
      # on progress updates; https://github.com/Julian/lean.nvim/issues/492 --
      # cancellation of requests whose results are no longer needed (handled
      # by the separate cancellation patch below). The live
      # reproduction delivered three ~6.6 MB goal responses. A single response
      # was already sufficient for multi-GiB UI growth, so cancellation alone
      # would not protect the current infoview from this failure mode.
      #
      # Bound the cached interactive-goal prefix BEFORE constructing widgets,
      # retain only the original count for the truncation notice, and let omitted
      # RPC references become collectible. Default: 100; configurable through
      # lean.setup({ infoview = { max_goals = ... } }). Do not deduplicate by goal
      # ID: the same goal can legitimately be shown in different tactic states.
      # JSON decoding and Lean's own repeated work still happen; this is a UI
      # allocation bound, not a repair for the upstream tactic/parser bug.
      # With 4,108 real goal entries (20,000 heartbeats), the patched path
      # rendered 100 goals / 7,606 positions at 146 MiB RSS, down from 671 MiB.
      #
      # GitHub metadata is a locked non-flake input so normal evaluation remains
      # pure/offline. `nix flake update` (or updating lean-repeat-issue alone)
      # refreshes its state; evaluating Neovim then throws if the issue closed.
      # Closure prompts REVIEW: an older project toolchain can still be affected.
      # https://github.com/Julian/lean.nvim/issues/492: own pending RPCs per pin,
      # cancel when its position/document/view options change or its window
      # closes, and coalesce repeated updates for the same in-flight state.
      # In the isolated comparison, cancelling a stale 10,273-goal request
      # reduced received data from 19 MB to 2 KB and Neovim RSS from 331 MiB
      # to 16 MiB; the new cursor position still received its correct goal.
      # The server's cancellation ACK took ~7 seconds, so this establishes a
      # client allocation benefit, not a reduction in Lean's elaboration CPU.
      #
      # Neovim swallows RequestCancelled ACKs instead of invoking the response
      # callback. Cancellation must therefore complete the awaiting coroutine
      # itself, exactly once. A successful reply racing with cancellation must
      # release its RPC references and must not cache or render stale goals.
      # Shared RPC connection handshakes and independent pins must survive.
      # A pin waiting for a shared connection can stop waiting independently.
      # With the production per-pin patch, moving off unfinished `repeat rw`
      # received 5 KB at 17 MiB RSS and rendered the correct single current goal.
      # As above, the issue-status guard refreshes through the lock file.
      patches = (old.patches or [ ]) ++ [
        ./patches/lean-infoview-goal-limit.patch
        ./patches/lean-infoview-rpc-cancellation.patch
      ];

      # Fixed upstream after v2026.4.1: null RPC docstrings decode to vim.NIL.
      postPatch = (old.postPatch or "") + ''
        substituteInPlace lua/lean/widget/interactive_code.lua \
          --replace-fail 'if info_popup.doc ~= nil then' \
          'if info_popup.doc ~= nil and info_popup.doc ~= vim.NIL then'

        substituteInPlace lua/lean/widget/interactive_code.lua \
          --replace-fail "    vim.lsp.util.show_document(links[1], 'utf-16', { focus = true })" \
          "    vim.api.nvim_exec_autocmds('User', { pattern = 'LeanInfoviewGoTo', modeline = false, data = { kind = kind } })
          vim.lsp.util.show_document(links[1], 'utf-16', { focus = true })"

        substituteInPlace lua/lean/widgets/GoToModuleLink.lua \
          --replace-fail '        vim.lsp.util.show_document(' \
          "        vim.api.nvim_exec_autocmds('User', { pattern = 'LeanInfoviewGoTo', modeline = false, data = { kind = 'definition' } })
              vim.lsp.util.show_document("
      '';
    });
in
{
  imports = [ wlib.wrapperModules.neovim ];

  # Keep the Helix query source available even when Neovim is started with
  # `-u NONE`, as the headless motion harnesses do.
  envDefault.NVIM_HELIX_QUERY_RUNTIME = "${pkgs.helix.runtime}/queries";

  # Use this directory itself as the wrapped Neovim config directory.
  settings.config_directory = ./.;
  # The community template writes lua/matugen.lua under the ordinary Neovim
  # config root. Keep that directory on runtimepath without executing its
  # init.lua, since the wrapper remains the authoritative editor config.
  settings.block_normal_config = lib.mkIf useNoctaliaTheme false;

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

            vim.g.helix_query_runtime = ${builtins.toJSON (pkgs.helix.runtime + "/queries")}
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
        nvim-web-devicons
        # git-prompt-string-lualine-nvim
        bufferline-nvim
        indent-blankline-nvim
      ];

      # GitHub-focused editing, review, and link-sharing integrations.
      github = with pkgs.vimPlugins; [
        octo-nvim
        gitlinker-nvim
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
        {
          name = "lean.nvim";
          data = leanNvim;
          before = [ "INIT_MAIN" ];
          config = /* lua */ ''
            require("lean").setup({ mappings = true })
          '';
        }
      ];

      # Non-essential integrations.
      fun = with pkgs.vimPlugins; [
        presence-nvim
      ] ++ lib.optionals enableKittyScrollback [
        {
          name = "kitty-scrollback.nvim";
          data = kitty-scrollback-nvim;
          config = /* lua */ ''
            require("axelcool1234.kitty_scrollback").setup()
          '';
        }
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

        # Styling, layout, and graph-like formats.
        "css"
        "dot"
        "scss"
        "tsx"

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
        "gleam"
        "javascript"
        "jq"
        "llvm"
        "mlir"
        "python"
        "rust"
        "tablegen"
        "typescript"

        # Useful for Tree-sitter-powered query editing and regex-aware motions.
        "query"
        "regex"
      ] pkgs.vimPlugins.nvim-treesitter-parsers ++ [
        # lean.nvim ships Lean queries, but the parser itself is packaged here.
        selfPkgs.treesitter-grammar-lean
      ];
    }
    // lib.optionalAttrs useNoctaliaTheme {
      # The community template owns matugen.lua and its SIGUSR1 reload hook.
      # This wrapper only supplies base16-nvim and invokes that module.
      theme = with pkgs.vimPlugins; [
        {
          name = "noctalia-theme";
          data = base16-nvim;
          before = [ "INIT_MAIN" ];
          config = /* lua */ ''
            local ok, matugen = pcall(require, "matugen")
            if ok then
              matugen.setup()
            end
          '';
        }
      ];
    };

  # Common tools this config shells out to.
  runtimePkgs = [
    pkgs.curl # For lean.nvim :Telescope loogle
    pkgs.fzf
    pkgs.fd
    pkgs.gh
    pkgs.gh-dash
    pkgs.ripgrep
    pkgs.wl-clipboard
    selfPkgs.jjui
    selfPkgs.zathura # VimTeX PDF viewer
  ];

  runtimeLibs = [
    pkgs.resvg # For lean.nvim widgets
  ];
}
