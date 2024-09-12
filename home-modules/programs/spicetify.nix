{ pkgs, inputs, lib, config, ... }:
let
    spicePkgs = inputs.spicetify-nix.legacyPackages.x86_64-linux;
in 
{    
  imports = [
      inputs.spicetify-nix.homeManagerModules.default
  ];
  options = {
    spicetify.enable =
      lib.mkEnableOption "enables spicetify config";
  };
  config = lib.mkIf config.spicetify.enable {
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "spotify"
    ];
    programs.spicetify = {
        enable = true;
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
