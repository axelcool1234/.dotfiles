{ lib, config, theme, ... }:
with lib;
let
  program = "avizo";
  program-module = config.modules.${program};
  themePalette = theme.requireThemeData "palette";
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf program-module.enable {
    services.avizo.enable = true;
    services.avizo.settings = {
      default = {
        background = lib.mkDefault "rgba(${lib.removePrefix "#" themePalette.overlay1}, 1)";
        time = lib.mkForce 2;
      };
    };
  };
}
