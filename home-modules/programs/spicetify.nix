{ pkgs, inputs, lib, config, ... }:
let
    spicePkgs = inputs.spicetify-nix.packages.x86_64-linux.default;
in 
{    
  imports = [
      inputs.spicetify-nix.homeManagerModule
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
