{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${lib.getExe pkgs.tuigreet} --time --time-format '%I:%M %p | %a | %F' --cmd '${inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.niri}/bin/niri-session'";
        user = "greeter";
      };
    };
  };

  users.users.greeter = {
    isNormalUser = false;
    description = "greetd greeter user";
    extraGroups = [ "video" "audio" ];
    linger = true;
  };

  programs.niri = {
    enable = true;
    package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  };
}
