{
  inputs,
  lib,
  config,
  ...
}:
with lib;
let
  program = "spicetify";
  program-module = config.modules.${program};
  spicePkgs = inputs.spicetify-nix.legacyPackages.x86_64-linux;
in
{
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
  ];
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    nixpkgs.config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "spotify"
      ];
    programs.${program} = {
      enable = true; # Enable Spicetify (It also installs Spotify)
      theme = spicePkgs.themes.catppuccin;
      colorScheme = "mocha";
      enabledExtensions = with spicePkgs.extensions; [
        adblock
        shuffle
        keyboardShortcut
        fullAppDisplay
      ];
      #windowManagerPatch = true;
      #spotifyPackage = (pkgs.callPackage ../../pkgs/spotify-adblock.nix { });
    };
  };
}
