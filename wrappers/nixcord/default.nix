{
  config,
  hostVars,
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktopShell == "noctalia";

  vencordSettings = {
    plugins.oneko.enable = true;

    # Noctalia writes the community Midnight theme to this filename. Enable it
    # only when Noctalia is the selected desktop shell.
    enabledThemes = lib.optionals useNoctaliaTheme [
      "noctalia.theme.css"
    ];
  };

  evaluated = inputs.nixpkgs.lib.nixosSystem {
    inherit system;

    modules = [
      inputs.nixcord.nixosModules.nixcord
      {
        programs.nixcord = {
          enable = true;
          user = "user";
          vesktop.enable = true;
          config = vencordSettings;
        };
      }
    ];
  };

  # Use Nixcord's normalization so plugin names and settings have the exact
  # JSON shape Vencord expects.
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
in
{
  imports = [ ./module.nix ];

  config = {
    package = evaluated.config.programs.nixcord.finalPackage.vesktop;
    settings = nixcordCore.mkVencordCfg vencordSettings;

    # Placement through Hjem is host policy, so keep the XDG-relative mapping
    # in this local instantiation rather than the reusable wrapper module.
    passthru.homeFiles = {
      "vesktop/settings/settings.json" = config.constructFiles.generatedSettings.outPath;
    };

    passthru.persist = {
      # TODO: Can probably persist just `sessionData` and `state.json`, not the
      # entire directory.
      homeDirectories = [ ".config/vesktop" ];
    };
  };
}
