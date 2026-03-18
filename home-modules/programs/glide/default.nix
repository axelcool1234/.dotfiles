{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  program = "glide";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf program-module.enable {
    home.packages = [
      (pkgs.callPackage ../../../pkgs/glide-browser.nix { })
    ];

    xdg.configFile."glide/glide.ts".source = ./glide.ts;
  };
}
