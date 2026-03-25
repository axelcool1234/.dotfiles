{
  inputs,
  lib,
  pkgs,
  config,
  theme,
  ...
}:
with lib;
let
  program = "spicetify";
  program-module = config.modules.${program};
  spicePkgs = inputs.spicetify-nix.legacyPackages.x86_64-linux;
  spicetifyProvider = theme.lookupProvider program;
  spicetifyThemeSource = theme.lookupAssetSource program;

  # Spicetify can consume structured providers that point at one packaged theme
  # under spicetify-nix, or fall back to asset-backed themes below.
  spicetifyThemePkg = theme.matchProvider program {
    null = null;
    structured = provider:
      if provider.attrPath == [ ] then
        null
      else
        builtins.foldl' (acc: name: builtins.getAttr name acc) spicePkgs.themes provider.attrPath;
    default = _: null;
  };

  spicetifyTheme =
    if spicetifyThemePkg != null then
      spicetifyThemePkg
    else if spicetifyThemeSource != null then
      {
        name = spicetifyProvider.options.name;
        src = spicetifyThemeSource;
        injectCss = spicetifyProvider.options.injectCss or true;
        injectThemeJs = spicetifyProvider.options.injectThemeJs or true;
        replaceColors = spicetifyProvider.options.replaceColors or true;
        homeConfig = spicetifyProvider.options.homeConfig or true;
        overwriteAssets = spicetifyProvider.options.overwriteAssets or false;
        additionalCss = spicetifyProvider.options.additionalCss or "";
        extraCommands = spicetifyProvider.options.extraCommands or "";
        extraPkgs = spicetifyProvider.options.extraPkgs or [ ];
      }
    else
      null;
  onekoExtension = {
    src = pkgs.fetchFromGitHub {
      owner = "kyrie25";
      repo = "spicetify-oneko";
      rev = "589a8cc3a3939b8c9fc4f2bd087ed433e9af5002";
      hash = "sha256-lestrf4sSwGbBqy+0J7u5IoU6xNKHh35IKZxt/phpNY=";
    };
    name = "oneko.js";
  };
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
        onekoExtension
      ];
      #windowManagerPatch = true;
      #spotifyPackage = (pkgs.callPackage ../../pkgs/spotify-adblock.nix { });
    } // lib.optionalAttrs (spicetifyTheme != null) {
      theme = spicetifyTheme;
      colorScheme = spicetifyProvider.options.colorScheme or "";
    };
  };
}
