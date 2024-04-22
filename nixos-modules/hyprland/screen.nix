{ pkgs, config, lib, ... }:

{
  config = lib.mkIf config.hyprland.enable {
    # Enable Gammastep Color Temperature
    services.geoclue2.appConfig = {
      "gammastep" = {
        isAllowed = true;
        isSystem = false;
        users = [ "1000" ];
      };
    };

    programs.light.enable = true;

    environment.systemPackages = with pkgs; [
      # wlsunset
      gammastep # Color Temperature
      brightnessctl # Color Temperature
    ];
  };
}
