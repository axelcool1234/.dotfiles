{
  lib,
  pkgs,
  ...
}:
let
  installer = pkgs.fetchurl {
    url = "https://mqreborn.com/StartDownload";
    sha256 = "0hh4c89vp0qai6av31l2b67iyi2jsaa6m8pn6ls7lnf9nlcjdgns";
    name = "InstallMQReborn.exe";
  };
in
pkgs.writeShellApplication {
  name = "mqreborn";

  runtimeInputs = [
    pkgs.coreutils
    pkgs.umu-launcher
  ];

  text = /* bash */ ''
    set -eu

    data_root="''${XDG_DATA_HOME:-$HOME/.local/share}/mqreborn"
    patcher_path="$data_root/drive_c/MQReborn/patcher/MQReborn Patcher.exe"

    export WINEPREFIX="$data_root"
    export GAMEID="mqreborn"

    mkdir -p "$data_root"

    if [ ! -f "$patcher_path" ]; then
      printf '%s\n' "MQReborn is not installed yet in $data_root." >&2
      printf '%s\n' "Launching the official installer through UMU/Proton..." >&2

      umu-run "${installer}"

      if [ ! -f "$patcher_path" ]; then
        printf '%s\n' "MQReborn installation was not completed." >&2
        printf '%s\n' "Expected patcher at: $patcher_path" >&2
        exit 1
      fi
    fi

    exec umu-run "$patcher_path" --no-sandbox --disable-gpu "$@"
  '';

  meta = {
    description = "Launch MQReborn through UMU/Proton with a self-managed prefix";
    homepage = "https://mqreborn.com/";
    license = lib.licenses.unfree;
    mainProgram = "mqreborn";
    platforms = lib.platforms.linux;
  };

  passthru.persist = {
    homeDirectories = [ ".local/share/mqreborn" ];
  };
}
