{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  program = "neovim";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    # for xdg.configFile, it's "nvim", not "neovim"
    xdg.configFile.nvim.source = ./.;

    programs.${program} = {
      enable = true;

      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      plugins = with pkgs.vimPlugins; [
        # Essentials
        plenary-nvim
        nvim-treesitter
        nvim-treesitter-parsers.nix
        nvim-treesitter-parsers.vim
        nvim-treesitter-parsers.vimdoc
        nvim-treesitter-parsers.typst
        nvim-treesitter-parsers.toml
        nvim-treesitter-parsers.rust
        nvim-treesitter-parsers.cpp
        nvim-treesitter-parsers.python
        nvim-treesitter-parsers.tablegen
        telescope-nvim
        telescope-fzf-native-nvim
        undotree

        # LSP
        nvim-lspconfig
        nvim-lint
        nvim-cmp
        cmp-nvim-lsp # Completion source for nvim builtin lsp
        cmp-buffer # Completion source for nvim-cmp
        cmp-path # Completion source for file system paths
        cmp-cmdline # Completion source for nvim's command line
        cmp-nvim-ultisnips # Completion source for ultisnips
        ultisnips
        friendly-snippets

        # Debugging
        nvim-dap
        nvim-dap-ui
        nvim-dap-virtual-text
        neotest

        # Editor
        which-key-nvim
        mini-icons # (gives icons for which-key)
        todo-comments-nvim
        gitsigns-nvim
        lualine-nvim
        lualine-lsp-progress
        # git-prompt-string-lualine-nvim
        bufferline-nvim
        indent-blankline-nvim
        vim-illuminate
        dressing-nvim
        precognition-nvim # (not in the Nix package manager yet!)

        # LaTeX
        vimtex # (could be replaced with texlab LSP's build command, but as of now this is fine)

        # Lean4
        lean-nvim

        # Rust
        rustaceanvim

        # Dafny
        vim-loves-dafny

        # Power user
        flash-nvim
        oil-nvim
        harpoon2
        overseer-nvim
        mini-move # (not in the Nix package manager yet!)
        firenvim

        # Fun
        presence-nvim

        # Themes
        catppuccin-nvim
        tokyonight-nvim
      ];
    };
  };
}
