{ pkgs, lib, ... }:
{
  home.file.".config/Vencord/themes/catppuccin-macchiato.theme.css" = {
    source = pkgs.fetchurl {
      url = "https://catppuccin.github.io/discord/dist/catppuccin-macchiato.theme.css";
      sha256 = "1dwggqap0n3sklnbwslhr8wni5hsmilv9db5l233xbnl9f7z31zq";
    };
  };
}
