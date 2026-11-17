{
  config,
  hostVars,
  lib,
  selfPkgs,
  ...
}:
{
  imports = [ ./module.nix ];

  config = {
    settings = {
      schema_version = 1;
      browser.terminal_command = lib.getExe selfPkgs.${hostVars.terminal};
    };

    passthru.homeFiles."luciole/config.toml" = config.passthru.generatedConfig;

    passthru.persist = {
      # Keep GUI overrides and the generated palette writable beside the base.
      homeDirectories = [
        ".config/luciole"
        ".local/state/luciole"
        ".local/share/luciole/scripts"
        ".local/share/Trash"
      ];
      homeFiles = [ ];
    };
  };
}
