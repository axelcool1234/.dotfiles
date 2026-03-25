{
  inputs,
  pkgs,
  ...
}:
{
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet \
        --time --time-format '%i:%m %p | %a • %h | %f' \
        --cmd ${
                inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.niri
              }/bin/niri-session";
      user = "greeter";
    };
  };

  programs.niri = {
    enable = true;
    package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  };
}
