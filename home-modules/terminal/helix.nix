{ pkgs, lib, config, ... }: {
  options = {
    helix.enable =
      lib.mkEnableOption "enables helix config";
  };
  config = lib.mkIf config.helix.enable {
    programs.helix = {
      enable = true;
      settings = {
        theme = "tokyonight";
        editor = {
          line-number = "relative";
          bufferline = "always";
          lsp.display-messages = true;

          mouse = false;
          auto-pairs = false;
          color-modes = true;

          indent-guides = {
            render = true;
          };
        };  
        keys = {
          normal = {
             up = "no_op";
             down = "no_op";
             left = "no_op";
             right = "no_op";
          };
          insert = {
             up = "no_op";
             down = "no_op";
             left = "no_op";
             right = "no_op";
          };
        };
      };
    };
  };
}
