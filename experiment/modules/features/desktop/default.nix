{
  self,
  lib,
  selfPkgs,
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
      selfPkgs.environment # Default interactive shell environment
      selfPkgs.desktop     # Default desktop/session package
    ];

    users.users.greeter = {
      isNormalUser = false;
      description = "greetd greeter user";
      extraGroups = [ "video" "audio" ];
      linger = true;
    };
  };
}
