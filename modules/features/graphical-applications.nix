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

  graphicalHomeFiles = selfPkgs.nixcord.passthru.homeFiles // musicHomeFiles;
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
  };

  services.flatpak = lib.mkIf (musicHostIntegration ? enableFlatpak) {
    enable = musicHostIntegration.enableFlatpak or false;
  };

  xdg.portal = lib.mkIf (musicHostIntegration ? portalConfig) (
    musicHostIntegration.portalConfig or { }
  );

  systemd.user.services = musicHostIntegration.userServices or { };

  preferences.impermanence.persist.homeDirectories = lib.mkAfter [
    # IndexedDB stores per-workspace app state that Slack uses to restore sessions.
    ".config/Slack/IndexedDB"
    # Local Storage holds Chromium key/value auth and team state for Slack.
    ".config/Slack/Local Storage"
    # Session Storage keeps transient session state needed to resume logged-in app views.
    ".config/Slack/Session Storage"
  ];

  preferences.impermanence.persist.homeFiles = lib.mkAfter [
    # Chromium cookie database; this is the core persisted web login state.
    ".config/Slack/Cookies"
    # SQLite sidecar for the cookie database.
    ".config/Slack/Cookies-journal"
    # Chromium network metadata associated with the current browser profile.
    ".config/Slack/Network Persistent State"
    # Slack's own workspace list and selected-workspace metadata.
    ".config/Slack/storage/root-state.json"
  ];

  environment.systemPackages = [
    selfPkgs.${hostVars.terminal} # Default terminal
    selfPkgs.${hostVars.browser} # Default browser
    musicPackage # Music
    selfPkgs.nixcord # Casual communication
    pkgs.slack # Work communication
    pkgs.pcmanfm # File manager
    selfPkgs.zathura # PDFs
    pkgs.imv # Images
    pkgs.mpv # Videos
  ];
}
