{
  pkgs,
  self,
  ...
}:
let
  mkDiskoInstall = host:
    if self.nixosConfigurations.${host}.config.preferences.impermanence.enable then
      pkgs.writeShellApplication {
        name = "disko-${host}-install";

        runtimeInputs = [
          pkgs.coreutils
          pkgs.util-linux
        ];

        text = ''
          set -euo pipefail

          umount -R /mnt/disko-install-root 2>/dev/null || true
          umount -R /mnt 2>/dev/null || true
          swapoff -a 2>/dev/null || true

          ${self.nixosConfigurations.${host}.config.system.build.diskoScript}

          nixos-install \
            --no-channel-copy \
            --no-root-password \
            --system ${self.nixosConfigurations.${host}.config.system.build.toplevel} \
            --root /mnt
        '';
      }
    else
      pkgs.writeShellApplication {
        name = "disko-${host}-install";

        text = ''
          echo "disko-${host}-install is disabled because preferences.impermanence.enable is false for ${host}." >&2
          exit 1
        '';
      };
in
{
  environment.systemPackages = [
    (mkDiskoInstall "legion")
    (mkDiskoInstall "fermi")
  ];
}
