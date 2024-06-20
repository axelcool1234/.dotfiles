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
        sha256 = "cFWDsNgyG/TInIfZjzM3htVkSma0ighed0UEU5qES2E=";
      };
    };
  };
}
