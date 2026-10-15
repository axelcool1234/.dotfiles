{
  lib,
  pkgs,
  ...
}:
let
  kkrieger = pkgs.fetchzip {
    url = "https://web.archive.org/web/20110718000154if_/http://kk.kema.at/files/kkrieger-beta.zip";
    sha256 = "146d16js8v3v8flqw290f4ccak87z8g3lr96dw1gfmrkj298rpgk";
    stripRoot = false;
  };
in
pkgs.writeShellApplication {
  name = "kkrieger";

  runtimeInputs = [ pkgs.wine ];

  text = /* bash */ ''
    data_root="''${XDG_DATA_HOME:-$HOME/.local/share}/kkrieger"

    mkdir -p "$data_root"
    export WINEPREFIX="$data_root"

    exec wine ${kkrieger}/pno0001.exe "$@"
  '';

  meta = {
    description = ".kkrieger, a 96k first-person shooter by .theprodukkt";
    homepage = "https://web.archive.org/web/20100304155706/http://www.theprodukkt.com/kkrieger";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "kkrieger";
    platforms = [ "x86_64-linux" ];
  };

  passthru.persist.homeDirectories = [ ".local/share/kkrieger" ];
}
