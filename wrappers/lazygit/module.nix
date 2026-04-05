{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
let
  yamlFmt = pkgs.formats.yaml { };
  hasStructuredSettings = config.settings != { };
  appendedSettings = lib.concatStringsSep "\n" (
    lib.filter (text: text != "") [
      config.extraSettings
      config."config.yml".content
    ]
  );
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = yamlFmt.type;
      default = { };
      description = ''
        LazyGit configuration written to `config.yml`.
      '';
    };

    extraSettings = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra YAML appended to the generated `config.yml`.

        Use this as an escape hatch for settings that are awkward to express via
        the structured `settings` attrset.
      '';
    };

    "config.yml" = lib.mkOption {
      type = wlib.types.file pkgs;
      default = {
        path = config.constructFiles.generatedConfig.path;
        content = "";
      };
      description = ''
        The LazyGit configuration file.

        Provide `.content` to append raw YAML after `settings` and
        `extraSettings`, or `.path` to point LazyGit at an existing config file.
      '';
    };

    generatedConfig.output = lib.mkOption {
      type = lib.types.str;
      default = config.outputName;
      description = ''
        The derivation output for the generated LazyGit configuration.
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.lazygit;

    flags."--use-config-file" = config."config.yml".path;

    passthru = {
      generatedConfig = config.constructFiles.generatedConfig.outPath;
    };

    drv.extraSettings = appendedSettings;
    drv.passAsFile = lib.mkIf (appendedSettings != "") [ "extraSettings" ];

    constructFiles.generatedConfig = {
      relPath = "${config.binName}-config/config.yml";
      output = lib.mkOverride 0 config.generatedConfig.output;
      content = if hasStructuredSettings then builtins.toJSON config.settings else "";
      builder = ''
        mkdir -p "$(dirname "$2")"
        ${lib.optionalString hasStructuredSettings ''
          ${pkgs.remarshal}/bin/json2yaml "$1" "$2"
        ''}
        ${lib.optionalString (!hasStructuredSettings) ''
          : > "$2"
        ''}
        ${lib.optionalString (appendedSettings != "") ''
          cat "$extraSettingsPath" >> "$2"
        ''}
      '';
    };
  };
}
