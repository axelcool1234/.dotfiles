{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
in
{
  imports = [ wlib.modules.default ];

  options.settings = lib.mkOption {
    type = jsonFormat.type;
    default = { };
    description = ''
      Vencord settings written to Vesktop's `settings/settings.json`.

      This wrapper exposes the generated file through
      `passthru.generatedSettings`; the host remains responsible for placing
      it in Vesktop's writable XDG configuration directory.
    '';
  };

  config = {
    package = lib.mkDefault pkgs.vesktop;

    constructFiles.generatedSettings = {
      relPath = "${config.binName}-config/settings/settings.json";
      content = builtins.toJSON config.settings;
    };

    passthru.generatedSettings = config.constructFiles.generatedSettings.outPath;

    meta = {
      description = "Vesktop with a generated declarative Vencord settings file";
      platforms = lib.platforms.linux;
    };
  };
}
