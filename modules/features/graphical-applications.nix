{
  baseVars,
  hostVars,
  lib,
  pkgs,
  selfPkgs,
  ...
}:
let
  musicPackage = selfPkgs.${hostVars.music};
  musicHomeFiles = musicPackage.passthru.homeFiles or { };
  musicHostIntegration = musicPackage.passthru.hostIntegration or { };

  graphicalHomeFiles =
    selfPkgs.nixcord.passthru.homeFiles // selfPkgs.luciole.passthru.homeFiles // musicHomeFiles;
in
{
  # Application wrappers own their generated configuration; the host only
  # decides where those artifacts are installed for the configured user.
  hjem.users.${baseVars.username} = {
    enable = true;
    clobberFiles = true;
    xdg.config.files = lib.mapAttrs (_path: source: {
      inherit source;
    }) graphicalHomeFiles;

    # Prefer Luciole for applications that call ShowItems/ShowFolders on D-Bus.
    xdg.data.files."dbus-1/services/org.freedesktop.FileManager1.service".source =
      "${selfPkgs.luciole}/share/dbus-1/services/dev.noctalia.luciole.FileManager1.service";
  };

  services.gvfs.enable = true;
  programs.dconf.enable = true;
  # Luciole supplies file pickers, so Niri no longer needs Nautilus on D-Bus.
  programs.niri.useNautilus = lib.mkIf (hostVars.compositor == "niri") false;
  xdg.mime.defaultApplications."inode/directory" = "dev.noctalia.luciole.desktop";

  services.flatpak = lib.mkIf (musicHostIntegration ? enableFlatpak) {
    enable = musicHostIntegration.enableFlatpak or false;
  };

  xdg.portal = lib.mkMerge [
    (musicHostIntegration.portalConfig or { })
    {
      enable = true;
      extraPortals = [ selfPkgs.luciole ];
      config.common."org.freedesktop.impl.portal.FileChooser" = [
        "luciole"
        "gtk"
      ];
      config.niri."org.freedesktop.impl.portal.FileChooser" = lib.mkForce [
        "luciole"
        "gtk"
      ];
    }
  ];

  systemd.user.services = musicHostIntegration.userServices or { };

  preferences.impermanence.persist.homeDirectories = lib.mkAfter [
    # Luciole shares editable bookmarks with GTK applications.
    ".config/gtk-3.0"
    # IndexedDB stores per-workspace app state that Slack uses to restore sessions.
    ".config/Slack/IndexedDB"
    # Local Storage holds Chromium key/value auth and team state for Slack.
    ".config/Slack/Local Storage"
    # Session Storage keeps transient session state needed to resume logged-in app views.
    ".config/Slack/Session Storage"
    # Slack atomically replaces root-state.json; persist its parent so workspace
    # state survives without replacing a persistence symlink or a mounted file.
    ".config/Slack/storage"
  ];

  preferences.impermanence.persist.homeFiles = lib.mkAfter [
    # Chromium cookie database; this is the core persisted web login state.
    ".config/Slack/Cookies"
    # SQLite sidecar for the cookie database.
    ".config/Slack/Cookies-journal"
    # Chromium regenerates Network Persistent State. Keeping that atomically
    # replaced file here makes subsequent activations fail on the regular file.
  ];

  environment.systemPackages = [
    selfPkgs.${hostVars.terminal} # Default terminal
    selfPkgs.${hostVars.browser} # Default browser
    musicPackage # Music
    selfPkgs.nixcord # Casual communication
    pkgs.slack # Work communication
    selfPkgs.luciole # File manager
    selfPkgs.zathura # PDFs
    pkgs.imv # Images
    pkgs.mpv # Videos
  ];
}
