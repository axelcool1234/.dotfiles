{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Reuse Nixcord's own normalization logic so the generated Vesktop settings
  # file has the same shape the upstream module would have written.
  nixcordCore = import (inputs.nixcord.outPath + "/modules/lib/core.nix") {
    inherit lib;
    parseRules = {
      upperNames = [ ];
      lowerPluginTitles = [ ];
      settingRenames = { };
    };
    libva = pkgs.libva;
    stdenv = pkgs.stdenv;
    electron_40 = pkgs.electron_40;
  };

  vesktopThemeConfig = {
    plugins.oneko.enable = true;

    # Noctalia writes `noctalia.theme.css` into Vesktop's local `themes/`
    # directory. Pre-enable it so the client picks it up on startup.
    enabledThemes = [ "noctalia.theme.css" ];
  };

  vesktopClientSettings = {
    # Keep Discord inside Vesktop's own title bar rather than the native system
    # one, otherwise the native title text color can get stuck on the previous
    # palette until the app is restarted.
    customTitleBar = true;
  };

  vesktopSettingsFile = pkgs.writeText "vesktop-settings.json" (
    builtins.toJSON (nixcordCore.mkVencordCfg vesktopThemeConfig)
  );

  vesktopClientSettingsFile = pkgs.writeText "vesktop-client-settings.json" (
    builtins.toJSON vesktopClientSettings
  );
in
{
  # Files to merge into the outer Hjem user block.
  homeFiles = {
    # Nixcord normally writes this file during activation. We recreate just the
    # bit we need here so Vesktop gets theme/plugin state without importing the
    # full Nixcord NixOS module.
    "vesktop/settings/settings.json" = vesktopSettingsFile;

    # Vesktop's own client settings live one level higher than Vencord's theme
    # config. This makes the app use Discord's custom title bar, which updates
    # with Noctalia's CSS on palette changes.
    "vesktop/settings.json" = vesktopClientSettingsFile;
  };
}
