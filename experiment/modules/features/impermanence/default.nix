{ ... }:
{
  imports = [
    ./options.nix
    ./assertions.nix
    ./persisted-paths.nix
    ./btrfs-rollback.nix
  ];
}
