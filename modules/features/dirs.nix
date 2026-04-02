{
  pkgs,
  baseVars,
  ...
}:
let
  userDirsConfig = pkgs.writeText "user-dirs.dirs" ''
    XDG_DESKTOP_DIR="$HOME/Desktop"
    XDG_DOWNLOAD_DIR="$HOME/Downloads"
    XDG_TEMPLATES_DIR="$HOME/Templates"
    XDG_PUBLICSHARE_DIR="$HOME/Public"
    XDG_DOCUMENTS_DIR="$HOME/Documents"
    XDG_MUSIC_DIR="$HOME/Music"
    XDG_PICTURES_DIR="$HOME/Pictures"
    XDG_VIDEOS_DIR="$HOME/Videos"
  '';
in
{
  hjem.users.${baseVars.username} = {
    enable = true;
    xdg.config.files."user-dirs.dirs".source = userDirsConfig;
  };
}
