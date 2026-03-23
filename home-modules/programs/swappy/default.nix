{ lib, config, ... }:
with lib;
let
  program = "swappy";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      settings = {
        Default = {
          save_dir = "$HOME/Pictures/Edits";
          save_filename_format = "swappy-%Y%m%d-%H%M%S.png";
          show_panel = false;
          line_size = 5;
          text_size = 20;
          text_font = "sans-serif";
          paint_mode = "brush";
          early_exit = false;
          fill_shape = false;
        };
      };
    };
  };
}
