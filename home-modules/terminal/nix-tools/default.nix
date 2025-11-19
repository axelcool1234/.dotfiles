{
  inputs,
  lib,
  config,
  ...
}:
with lib;
let
  module = "nix-tools";
in
{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
  ];
  options.modules.${module} = {
    enable = mkEnableOption "enables ${module}";
  };
  config = mkIf config.modules.${module}.enable {
    programs.nh.enable = true;

    programs.direnv.enable = true;
    programs.direnv.nix-direnv.enable = true; # TODO: Find the alternative that has a daemon maybe

    programs.nix-init.enable = true;
    programs.nix-index-database.comma.enable = true;

    # TODO: nix-index provides a command-not-found for nushell, but it's slow compared
    # to the default. I'm not sure why. Figure this out.
    programs.nix-index.enableBashIntegration = false;
    programs.nix-index.enableZshIntegration = false;
    programs.command-not-found.enable = true;
  };
}
