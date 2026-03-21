{ lib, config, themes, theme, ... }:
let
  grubProvider = themes.helpers.getAppProvider theme "grub";
  grubThemePackage =
    if grubProvider != null && grubProvider.type == "asset" then
      themes.helpers.resolveAssetSource grubProvider
    else
      null;
in
{
  options = {
    grub.enable =
      lib.mkEnableOption "enables grub";
  };
  config = lib.mkIf config.grub.enable {
    boot.loader.efi.efiSysMountPoint = "/boot";
    boot.loader.efi.canTouchEfiVariables = true;

    boot.loader.grub = {
      enable = true;
      efiSupport = true;
      useOSProber = true;
      configurationLimit = 10;
      device = "nodev"; # efi only
    } // lib.optionalAttrs (grubThemePackage != null) {
      theme = grubThemePackage;
    };
  };
}
