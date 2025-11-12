{ lib, config, ... }:
with lib;
let
  program = "git";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      userName = "Axel Sorenson";
      userEmail = "AxelPSorenson@gmail.com";
      extraConfig = {
        init = {
          defaultBranch = "main";
        };
      };
    };
  };
}
