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
      settings = {
        user.name = "Axel Sorenson";
        user.email = "AxelPSorenson@gmail.com";
        init = {
          defaultBranch = "main";
        };
      };
    };
  };
}
