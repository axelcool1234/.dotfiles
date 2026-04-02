{
  lib,
  pkgs,
  baseVars,
  ...
}:
let
  # https://gitlab.freedesktop.org/xdg/xdg-user-dirs/-/merge_requests/24
  userDirsConfig = pkgs.writeText "user-dirs.dirs" ''
    XDG_DOWNLOAD_DIR="$HOME/Downloads"
    XDG_PICTURES_DIR="$HOME/Pictures"
    XDG_VIDEOS_DIR="$HOME/Videos"
    XDG_PROJECTS_DIR="$HOME/Projects"
  '';
in
{
  hjem.users.${baseVars.username} = {
    enable = true;
    xdg.config.files."user-dirs.dirs".source = userDirsConfig;
  };

  preferences.impermanence.persist.homeDirectories = [
    "Downloads"
    "Pictures"
    "Videos"
    "Projects"
  ];
}
