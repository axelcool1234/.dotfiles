{
  config,
  hostVars,
  lib,
  ...
}:
let
  runtimeHome = config.outOfStoreConfig;
  persistRoot =
    assert lib.hasPrefix ''${"$"}HOME/'' runtimeHome;
    lib.removePrefix ''${"$"}HOME/'' runtimeHome;
in
{
  imports = [ ./module.nix ];

  config = {
    settings.theme = lib.mkIf (hostVars.desktop-shell == "noctalia-shell") (lib.mkDefault "noctalia");

    settings.packages = lib.mkDefault [
      "npm:@tmustier/pi-usage-extension@0.9.4"
      "npm:pi-tasks@0.2.6"
      "git:github.com/m7l5/pi-msg@d65a741887f0c3cbf749b7f4a8fa017422acd10a"
      "npm:pi-web-access@0.28.0"
      "npm:pi-background-tasks@2.5.0"
    ];

    passthru.persist = {
      homeDirectories = [
        persistRoot
        # pi-msg deliberately stores its sockets, registry, and offline inbox
        # beside the agent directory rather than underneath it.
        ".pi/msg"
      ];
      homeFiles = [ ];
    };
  };
}
