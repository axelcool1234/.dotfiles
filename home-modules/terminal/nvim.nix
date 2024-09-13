{ pkgs, lib, config, ... }: 

let
  precognition-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "precognition-nvim";
    src = pkgs.fetchFromGitHub {
      owner = "tris203";
      repo = "precognition.nvim";
      rev = "v1.0.0"; # Update this to the latest tag or commit hash
      sha256 = "0csph3ww7vhrsxybzabvnv8ncrbif8kkh2v076r05fkxzrbri982"; # Obtain this hash from an error message or use `nix-prefetch-url`
    };
  };
  mini-move = pkgs.vimUtils.buildVimPlugin {
    name = "mini-move";
    src = pkgs.fetchFromGitHub {
      owner = "echasnovski";
      repo = "mini.move";
      rev = "v0.13.0";
      sha256 = "11yqz3w5bbddgx59dvrg3vglidymdqy6zc2bjcqkjl7g54ng5f9c";   
    };
  };
  mini-icons = pkgs.vimUtils.buildVimPlugin {
    name = "mini-icons";
    src = pkgs.fetchFromGitHub {
      owner = "echasnovski";
      repo = "mini.icons";
      rev = "2d89252993fec829b24720097a687412d10f6c85";
      sha256 = "1qg06xia1sm67b10sf6vdhmma9xmwkj7hzlk5dyfg25a7xmf2107";
    };
  };
in
{  
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
        telescope-fzf-native-nvim
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

        # Rust
        rustaceanvim

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
