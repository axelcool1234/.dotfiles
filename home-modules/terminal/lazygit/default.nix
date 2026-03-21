{ lib, config, theme, ... }:
with lib;
let
  program = "lazygit";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      settings.gui.theme = {
        lightTheme = theme.mode == "light";
        activeBorderColor = [ (theme.hex "green") "bold" ];
        inactiveBorderColor = [ (theme.hex "text") ];
        optionsTextColor = [ (theme.hex "blue") ];
        selectedLineBgColor = [ (theme.hex "surface0") ];
        selectedRangeBgColor = [ (theme.hex "surface0") ];
        cherryPickedCommitBgColor = [ (theme.hex "teal") ];
        cherryPickedCommitFgColor = [ (theme.hex "blue") ];
        unstagedChangesColor = [ (theme.hex "red") ];
      };
    };
  };
}
