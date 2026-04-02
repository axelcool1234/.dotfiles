{ ... }:
{
  imports = [
    ./impermanence/options.nix
    ./impermanence/assertions.nix
    ./impermanence/persisted-paths.nix
    ./impermanence/btrfs-rollback.nix
    ./impermanence/disko.nix
  ];

  preferences.impermanence.persist.systemDirectories = [
    "/var/log"
    "/var/lib/nixos"
  ];

  preferences.impermanence.persist.systemFiles = [
    "/etc/machine-id"
  ];

  preferences.impermanence.persist.homeDirectories = [
    ".dotfiles"
    { directory = ".ssh"; mode = "0700"; }
  ];
}
