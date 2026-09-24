{
  hostVars,
  lib,
  ...
}:
{
  imports = [ ./module.nix ];

  config = {
    settings = {
      options = {
        # Nix owns application updates and desktop-session startup.
        autoUpdates = false;
        startAtLogin = false;
      };

      plugins."do-not-track" = {
        enabled = true;
        cache = true;
        blocker = "In player";
        additionalBlockLists = [ ];
        disableDefaultLists = false;
      };
    };

    themes = lib.optionals (hostVars.desktopShell == "noctalia") [
      "noctalia.css"
    ];

    liveThemeReload.enable = hostVars.desktopShell == "noctalia";

    passthru.persist = {
      homeDirectories = [ ".config/YouTube Music" ];
      homeFiles = [ ];
    };
  };
}
