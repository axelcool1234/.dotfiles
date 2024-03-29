{ pkgs, lib, config, ... }: {
  options = {
    vim.enable =
      lib.mkEnableOption "enables vimrc config";
  };
  config = lib.mkIf config.vim.enable {
    # xdg.configFile.vim.source = ./.vimrc;
    programs.vim = {
      enable = true;
      extraConfig = ''
        au bufread,bufnewfile *.g set filetype=antlr3
        au bufread,bufnewfile *.g4 set filetype=antlr4

        " Disable arrow keys
          noremap <Up> <Nop>
          noremap <Down> <Nop>
          noremap <Left> <Nop>
          noremap <Right> <Nop>

          " Disable mouse
          set mouse=

          " Enable line numbers
          set number

          " Persist highlighting after indents
          :vnoremap < <gv
          :vnoremap > >gv
      '';
    };
  };
}
