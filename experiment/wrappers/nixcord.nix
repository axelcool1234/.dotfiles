{
  inputs,
  pkgs,
  wlib,
  system,
  ...
}:
let
  evaluated = inputs.nixpkgs.lib.nixosSystem {
    inherit system;

    modules = [
      inputs.nixcord.nixosModules.nixcord
      {
        programs.nixcord = {
          enable = true;
          user = "user";
          vesktop.enable = true;
          config.plugins.oneko.enable = true;
        };
      }
    ];
  };
in
{
  imports = [ wlib.modules.default ];

  config.package = evaluated.config.programs.nixcord.finalPackage.vesktop;
}
