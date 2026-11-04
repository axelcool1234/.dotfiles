{ lib, pkgs, ... }:
pkgs.writeShellApplication {
  name = "system-health-check";

  runtimeInputs = [
    pkgs.bluez
    pkgs.coreutils
    pkgs.iproute2
    pkgs.procps
    pkgs.systemd
    pkgs.util-linux
  ];

  text = ''
    exec ${pkgs.python3}/bin/python3 ${./health_check.py} "$@"
  '';

  meta = {
    description = "Collect a read-only NixOS health snapshot for diagnosis";
    mainProgram = "system-health-check";
    platforms = lib.platforms.linux;
  };
}
