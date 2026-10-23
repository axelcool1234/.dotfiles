{ selfPkgs, ... }:
{
  programs.steam.enable = true;

  preferences.impermanence.persist.homeDirectories = [
    # Steam client state, installed games, Workshop content, and userdata.
    ".local/share/Steam"

    # Caves of Qud saves, settings, logs, and local mods.
    ".config/unity3d/Freehold Games/CavesOfQud"
  ];

  environment.systemPackages = [
    selfPkgs.mqreborn
  ];
}
