{
  config,
  lib,
  pkgs,
  selfPkgs,
  ...
}:
{
  config = lib.mkIf (config.preferences.desktop == "niri") {
    programs.niri = {
      enable = true;
      package = selfPkgs.niri;
    };

    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${lib.getExe pkgs.tuigreet} --time --time-format '%I:%M %p | %a | %F' --cmd '${lib.getExe' selfPkgs.niri "niri-session"}'";
        user = "greeter";
      };
    };
  };
}
