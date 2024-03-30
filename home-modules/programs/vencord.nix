{ pkgs, lib, config, ... }:
{
  options = {
    vencord.enable =
      lib.mkEnableOption "enables vencord config";
  };
  config = lib.mkIf config.vencord.enable {
    home.file.".config/Vencord/themes/catppuccin-mocha.theme.css" = {
      source = pkgs.fetchurl {
        url = "https://catppuccin.github.io/discord/dist/catppuccin-mocha.theme.css";
        sha256 = "1xfi3pqkwvwr4sjxdrz07d7pvmpxnc71xk43xv10pxcficb5rgs4";
      };
    };
  };
}
