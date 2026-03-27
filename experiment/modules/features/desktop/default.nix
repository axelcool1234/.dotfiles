{
  self,
  lib,
  selfPkgs,
  pkgs,
  ...
}:
{
  imports = [ ./niri.nix ];

  options.preferences.desktop = lib.mkOption {
    type = lib.types.enum [ "niri" ];
    default = self.defaults.desktop;
    description = "Desktop implementation to enable.";
  };

  config = {
    _module.args.selfPkgs = selfPkgs;

    environment.systemPackages = [
      selfPkgs.terminal  # Default terminal
      selfPkgs.browser   # Default browser
      selfPkgs.spicetify # Music
      selfPkgs.nixcord   # Casual communication
      pkgs.slack         # Work communication
      pkgs.pcmanfm       # File Manager
    ];

    users.users.greeter = {
      isNormalUser = false;
      description = "greetd greeter user";
      extraGroups = [ "video" "audio" ];
      linger = true;
    };
  };
}
