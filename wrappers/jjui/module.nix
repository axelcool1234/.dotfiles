{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
let
  tomlFmt = pkgs.formats.toml { };
  hasStructuredSettings = config.settings != { };
  appendedSettings = lib.concatStringsSep "\n" (
    lib.filter (text: text != "") [
      config.extraSettings
      config."config.toml".content
    ]
  );
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = tomlFmt.type;
      default = { };
      description = ''
        jjui configuration written to `config.toml`.

        See <https://idursun.github.io/jjui/customization/config-toml/> for
        the supported schema.
      '';
    };

    extraSettings = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra TOML appended to the generated `config.toml`.

        Use this as an escape hatch for settings that are awkward to express via
        the structured `settings` attrset.
      '';
    };

    "config.toml" = lib.mkOption {
      type = wlib.types.file pkgs;
      default = {
        path = config.constructFiles.generatedConfig.path;
        content = "";
      };
      description = ''
        The jjui configuration file.

        Provide `.content` to append raw TOML after `settings` and
        `extraSettings`, or `.path` to point jjui at an existing config file.
      '';
    };

    generatedConfig.output = lib.mkOption {
      type = lib.types.str;
      default = config.outputName;
      description = ''
        The derivation output for the generated jjui configuration.
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.jjui;

    env.JJUI_CONFIG_DIR = dirOf config."config.toml".path;

    passthru.generatedConfig = config.constructFiles.generatedConfig.outPath;

    drv.extraSettings = appendedSettings;
    drv.passAsFile = lib.mkIf (appendedSettings != "") [ "extraSettings" ];

    constructFiles.generatedConfig = {
      relPath = "${config.binName}-config/config.toml";
      output = lib.mkOverride 0 config.generatedConfig.output;
      content = if hasStructuredSettings then builtins.toJSON config.settings else "";
      builder = ''
        mkdir -p "$(dirname "$2")"
        ${lib.optionalString hasStructuredSettings ''
          ${pkgs.remarshal}/bin/json2toml "$1" "$2"
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
