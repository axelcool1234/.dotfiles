{ pkgs, lib, config, inputs, ... }:
{
  options = {
    waybar.enable =
      lib.mkEnableOption "enables waybar config";
  };
  config = lib.mkIf config.waybar.enable {
    programs.waybar = {
        enable = true;
    };
    home.file.".config/waybar" = {
        source = ../waybar;
        recursive = true;
    };

    home.packages = with pkgs; [
      (callPackage ./mediaplayer.nix { } )  
    ];
  };
}
