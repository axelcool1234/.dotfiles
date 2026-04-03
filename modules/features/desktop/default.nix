{
  config,
  hostVars,
  self,
  lib,
  selfPkgs,
  ...
}:
{
  imports = [ ./niri.nix ];

  options.preferences.desktop = lib.mkOption {
    type = lib.types.enum [ "niri" ];
    default = hostVars.desktop;
    description = "Desktop implementation to enable.";
  };

  config = {
    _module.args.selfPkgs = selfPkgs;

    environment.systemPackages = [
      selfPkgs.environment # Default interactive shell environment
      selfPkgs.${config.preferences.desktop} # Default desktop/session package
    ];

    users.users.greeter = {
      isNormalUser = false;
      description = "greetd greeter user";
      extraGroups = [ "video" "audio" ];
      linger = true;
    };
  };
}
