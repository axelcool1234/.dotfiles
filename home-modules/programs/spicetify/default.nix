{
  inputs,
  lib,
  config,
  themes,
  theme,
  ...
}:
with lib;
let
  program = "spicetify";
  program-module = config.modules.${program};
  spicePkgs = inputs.spicetify-nix.legacyPackages.x86_64-linux;
  spicetifyProvider = themes.helpers.getAppProvider theme "spicetify";
  spicetifyThemePkg =
    if spicetifyProvider == null || spicetifyProvider.type != "package" then
      null
    else
      builtins.foldl' (acc: name: builtins.getAttr name acc) spicePkgs.themes spicetifyProvider.attrPath;
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
      enabledExtensions = with spicePkgs.extensions; [
        adblock
        shuffle
        keyboardShortcut
        fullAppDisplay
      ];
      #windowManagerPatch = true;
      #spotifyPackage = (pkgs.callPackage ../../pkgs/spotify-adblock.nix { });
    } // lib.optionalAttrs (spicetifyThemePkg != null) {
      theme = spicetifyThemePkg;
      colorScheme = spicetifyProvider.options.colorScheme;
    };
  };
}
