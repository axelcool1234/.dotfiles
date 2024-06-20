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

      plugins = [

        # Essentials
        pkgs.vimPlugins.nvim-treesitter
        pkgs.vimPlugins.nvim-treesitter-parsers.nix
      	pkgs.vimPlugins.nvim-treesitter-parsers.vim
	pkgs.vimPlugins.nvim-treesitter-parsers.vimdoc
      	pkgs.vimPlugins.nvim-treesitter-parsers.toml
      	pkgs.vimPlugins.nvim-treesitter-parsers.rust
      	pkgs.vimPlugins.nvim-treesitter-parsers.cpp
      	pkgs.vimPlugins.nvim-treesitter-parsers.python
      	pkgs.vimPlugins.telescope-nvim
      	pkgs.vimPlugins.undotree

        # Themes
        pkgs.vimPlugins.catppuccin-nvim
        pkgs.vimPlugins.tokyonight-nvim      
      ];

    };
  };
}
