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
        plenary-nvim
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
        nvim-lint
        nvim-cmp
        cmp-nvim-lsp       # Completion source for nvim builtin lsp
        cmp-buffer         # Completion source for nvim-cmp
        cmp-path           # Completion source for file system paths
        cmp-cmdline        # Completion source for nvim's command line
        cmp-nvim-ultisnips # Completion source for ultisnips
        ultisnips
        friendly-snippets

        # Debugging
        nvim-dap
        nvim-dap-ui
        nvim-dap-virtual-text

        # Editor
        which-key-nvim
        todo-comments-nvim
        gitsigns-nvim
        lualine-nvim
        lualine-lsp-progress
        # git-prompt-string-lualine-nvim
        bufferline-nvim
        indent-blankline-nvim
        vim-illuminate
        # precognition-nvim (not in the Nix package manager yet!)

        # LaTeX
        vimtex # (could be replaced with texlab LSP's build command, but as of now this is fine)

        # Rust
        rustaceanvim

        # Power user
        flash-nvim
        oil-nvim

        # Fun
        presence-nvim

        # Themes
        catppuccin-nvim
        tokyonight-nvim      
      ];

    };
  };
}
