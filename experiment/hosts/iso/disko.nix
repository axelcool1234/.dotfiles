{
  pkgs,
  ...
}:
let
  diskoInstall = pkgs.writeShellApplication {
    name = "disko-install";

    runtimeInputs = [
      pkgs.nix
      pkgs.util-linux
    ];

    text = ''
      set -euo pipefail

      if [ "$#" -gt 2 ]; then
        echo "usage: disko-install <legion|fermi> [flake_ref]" >&2
        exit 1
      fi

      host="''${1:-}"
      flake_ref="''${2:-.}"

      case "$host" in
        legion|fermi)
          ;;
        *)
          echo "usage: disko-install <legion|fermi> [flake_ref]" >&2
          exit 1
          ;;
      esac

      out_link="/tmp/disko-$host-install"

      if [ "$(nix eval "$flake_ref#nixosConfigurations.$host.config.preferences.impermanence.enable" --json)" != "true" ]; then
        echo "disko-install is disabled because preferences.impermanence.enable is false for $host." >&2
        exit 1
      fi

      rm -f "$out_link" "$out_link-1"

      nix build \
        "$flake_ref#nixosConfigurations.$host.config.system.build.toplevel" \
        "$flake_ref#nixosConfigurations.$host.config.system.build.diskoScript" \
        --out-link "$out_link"

      umount -R /mnt/disko-install-root 2>/dev/null || true
      umount -R /mnt 2>/dev/null || true
      swapoff -a 2>/dev/null || true

      "$out_link-1"

      nixos-install \
        --no-channel-copy \
        --no-root-password \
        --system "$out_link" \
        --root /mnt
    '';
  };
in
{
  environment.systemPackages = [ diskoInstall ];
}
