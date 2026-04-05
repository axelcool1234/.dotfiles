{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
let
  kittyKeyValue = {
    listsAsDuplicateKeys = true;
    mkKeyValue = lib.generators.mkKeyValueDefault { } " ";
  };

  kittyKeyValueFormat = pkgs.formats.keyValue kittyKeyValue;
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = kittyKeyValueFormat.type;
      default = { };
      description = ''
        Configuration written to `kitty.conf`.

        Kitty uses a line-oriented `name value` format where some keys such as
        `map` and `symbol_map` may be repeated multiple times.
      '';
    };

    extraSettings = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra lines appended to the generated `kitty.conf`.

        Use this for ordering-sensitive directives or raw settings that are
        awkward to express through the structured `settings` attrset.
      '';
    };

    "kitty.conf" = lib.mkOption {
      type = wlib.types.file pkgs;
      default = {
        path = config.constructFiles.generatedConfig.path;
        content = "";
      };
      description = ''
        The Kitty configuration file.

        Provide `.content` to append raw config lines after `settings` and
        `extraSettings`, or `.path` to point Kitty at an existing `kitty.conf`.
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.kitty;

    passthru.generatedConfig = config.constructFiles.generatedConfig.outPath;

    constructFiles.generatedConfig = {
      relPath = "kitty.conf";
      content =
        lib.generators.toKeyValue kittyKeyValue config.settings
        + lib.optionalString (config.extraSettings != "") "\n${config.extraSettings}\n"
        + lib.optionalString (config."kitty.conf".content != "") "\n${config."kitty.conf".content}\n";
    };
  };
}
