{ config, lib, ... }:
let
  cfg = config.preferences.impermanence;

  subvolumeNames = [
    cfg.rootSubvolume
    cfg.nixSubvolume
    cfg.persistenceSubvolume
  ] ++ lib.optionals (cfg.homeSubvolume != null) [ cfg.homeSubvolume ];

  uniqueSubvolumeNames = lib.unique subvolumeNames;

  isRelativeSubvolumeName = value:
    value != "" && !(lib.hasPrefix "/" value);
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.btrfsDevice != null;
        message = "Set preferences.impermanence.btrfsDevice before enabling impermanence.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.persistenceRoot;
        message = "preferences.impermanence.persistenceRoot must be an absolute path like /persist.";
      }
      {
        assertion = cfg.persistenceRoot != "/";
        message = "preferences.impermanence.persistenceRoot must not be /.";
      }
      {
        assertion = cfg.user != "";
        message = "preferences.impermanence.user must not be empty.";
      }
      {
        assertion = cfg.oldRootsRetentionDays >= 0;
        message = "preferences.impermanence.oldRootsRetentionDays must be 0 or greater.";
      }
      {
        assertion = builtins.all isRelativeSubvolumeName subvolumeNames;
        message = "Impermanence subvolume names must be non-empty relative names without a leading /.";
      }
      {
        assertion = isRelativeSubvolumeName cfg.oldRootsDirectory;
        message = "preferences.impermanence.oldRootsDirectory must be a non-empty relative name without a leading /.";
      }
      {
        assertion = builtins.length uniqueSubvolumeNames == builtins.length subvolumeNames;
        message = "Impermanence subvolume names must be distinct: root, nix, persist, and optional home must not reuse the same name.";
      }
      {
        assertion = !(builtins.elem cfg.oldRootsDirectory subvolumeNames);
        message = "preferences.impermanence.oldRootsDirectory must not reuse the same name as one of the mounted subvolumes.";
      }
    ];
  };
}
