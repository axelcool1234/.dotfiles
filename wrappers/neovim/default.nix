{
  hostVars,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktop-shell == "noctalia-shell";
in
{
  imports = [ wlib.wrapperModules.neovim ];

  # Use this directory itself as the wrapped Neovim config directory.
  settings.config_directory = ./.;

  env = lib.optionalAttrs useNoctaliaTheme {
    NVIM_ENABLE_NOCTALIA_THEME = "1";
  };

  # Bundle the plugins your copied config expects to exist.
  specs.general = with pkgs.vimPlugins; [
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

    # Editor UX
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
    precognition-nvim

    # Language support
    vimtex
    lean-nvim
    rustaceanvim

    # Navigation / task helpers
    flash-nvim
    oil-nvim
    harpoon2
    overseer-nvim
    mini-move

    # Fun
    presence-nvim
  ] ++ lib.optionals useNoctaliaTheme [
    base16-nvim
  ];

  # Common tools this config shells out to.
  extraPackages = [
    pkgs.fd
    pkgs.ripgrep
  ];
}
