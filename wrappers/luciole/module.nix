{
  config,
  inputs,
  lib,
  pkgs,
  system,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options.settings = lib.mkOption {
    inherit (pkgs.formats.toml { }) type;
    default = { };
    description = "Luciole settings for the validated base config.toml.";
  };

  config = {
    package = lib.mkDefault inputs.luciole.packages.${system}.default;

    # Send both D-Bus activation services through the same wrapper as the CLI.
    filesToPatch = [
      "share/applications/*.desktop"
      "share/dbus-1/services/*.service"
    ];

    passthru = (config.package.passthru or { }) // {
      generatedConfig = import "${inputs.luciole}/nix/config_file.nix" {
        inherit pkgs;
        inherit (config) package settings;
      };
    };
  };
}
