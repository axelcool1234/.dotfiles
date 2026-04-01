{ ... }:
{
  /*
    This file is the Fermi-local home for the eventual Disko layout.

    It intentionally stays a no-op for now until this host is ready to opt in to
    the new disk layout.

    The intended contents for this file are:
    - import the Disko module when the host is ready to opt in
    - target the final stable disk identifier for the machine
    - define EFI + swap + btrfs partitions
    - create subvolumes named `root`, `nix`, and `persist`
    - keep `/home` ephemeral by default and persist selected paths via
      `preferences.impermanence.persist.*`
  */
}
