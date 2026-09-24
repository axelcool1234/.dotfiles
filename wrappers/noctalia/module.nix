{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = wlib.types.structuredValueWith {
        nullable = false;
        typeName = "TOML";
      };
      default = { };
      description = ''
        Declarative Noctalia v5 configuration, rendered as config.toml.
        Runtime changes made in the settings UI are stored separately in the
        Noctalia state directory and override this base configuration.
      '';
    };

    checkConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to validate the generated Noctalia configuration at build time.";
    };

    generatedConfig.output = lib.mkOption {
      type = lib.types.str;
      default = config.outputName;
      description = "Derivation output containing the generated Noctalia configuration.";
    };

    generatedConfig.placeholder = lib.mkOption {
      type = lib.types.str;
      default = "${placeholder config.generatedConfig.output}/${config.binName}-config";
      readOnly = true;
      description = "Build-time placeholder for the generated NOCTALIA_CONFIG_HOME root.";
    };
  };

  config = {
    package = lib.mkDefault pkgs.noctalia;

    # NOCTALIA_CONFIG_HOME has XDG-home semantics: Noctalia appends its own
    # `noctalia/` directory. Keep this base layer immutable while allowing the
    # GUI to write overrides to the ordinary XDG state directory.
    env.NOCTALIA_CONFIG_HOME = config.generatedConfig.placeholder;

    constructFiles.config = {
      relPath = "${config.binName}-config/noctalia/config.toml";
      output = config.generatedConfig.output;
      content = builtins.toJSON config.settings;
      builder = ''
        ${pkgs.remarshal}/bin/json2toml "$1" "$2"
        ${lib.optionalString config.checkConfig ''
          ${lib.getExe config.package} config validate "$2"
        ''}
      '';
    };

    passthru.generatedConfig = "${
      config.wrapper.${config.generatedConfig.output}
    }/${config.binName}-config/noctalia";

    meta = {
      description = "Noctalia v5 with an immutable declarative base config and writable runtime overrides";
      platforms = lib.platforms.linux;
    };
  };
}
