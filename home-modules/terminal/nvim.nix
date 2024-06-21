{ pkgs, lib, config, ... }: {  
  options = {
    nvim.enable = 
      lib.mkEnableOption "enables nvim config";
  };
  config = lib.mkIf config.nvim.enable {
    xdg.configFile.nvim.source = ./nvim;

    programs.neovim = {
      enable = true;

      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      plugins = with pkgs.vimPlugins; [
        # Essentials
        nvim-treesitter
        nvim-treesitter-parsers.nix
      	nvim-treesitter-parsers.vim
      	nvim-treesitter-parsers.vimdoc
      	nvim-treesitter-parsers.toml
      	nvim-treesitter-parsers.rust
      	nvim-treesitter-parsers.cpp
      	nvim-treesitter-parsers.python
      	telescope-nvim
      	undotree

        # LSP
        nvim-lspconfig
        nvim-cmp
        cmp-nvim-lsp       # Completion source for nvim builtin lsp
        cmp-buffer         # Completion source for nvim-cmp
        cmp-path           # Completion source for file system paths
        cmp-cmdline        # Completion source for nvim's command line
        cmp-nvim-ultisnips # Completion source for ultisnips
        ultisnips
        friendly-snippets

        # Themes
        catppuccin-nvim
        tokyonight-nvim      
      ];

    };
  };
}
