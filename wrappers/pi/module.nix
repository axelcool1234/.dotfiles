{
  config,
  inputs,
  lib,
  pkgs,
  system,
  wlib,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  runtimeConfigDir = config.outOfStoreConfig;
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = ''
        Pi settings merged into the writable runtime `settings.json`.

        Wrapper-managed values take precedence while settings not declared here
        remain available for Pi to manage interactively.
      '';
    };

    outOfStoreConfig = lib.mkOption {
      type = lib.types.str;
      default = ''${"$"}HOME/.pi/agent'';
      example = ''${"$"}HOME/.local/share/pi/agent'';
      description = ''
        Writable Pi agent directory. The wrapper exports
        `PI_CODING_AGENT_DIR` to this path and synchronizes the declared
        settings into it before Pi starts.
      '';
    };

    autoSyncConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to merge the generated settings into the writable Pi agent
        directory each time the wrapper starts.
      '';
    };

    generatedConfig.output = lib.mkOption {
      type = lib.types.str;
      default = config.outputName;
      description = "The derivation output for the generated Pi settings.";
    };
  };

  config = {
    package = lib.mkDefault inputs.llm-agents.packages.${system}.pi;

    # Pi's package manager needs npm for npm sources and Git for Git sources.
    # xdg-open lets pi-web-access launch its curator UI on Linux.
    runtimePkgs = [
      pkgs.git
      pkgs.nodejs
      pkgs.xdg-utils
    ];

    envDefault.PI_CODING_AGENT_DIR = {
      data = config.outOfStoreConfig;
      esc-fn = wlib.escapeShellArgWithEnv;
    };

    passthru = {
      generatedConfig = config.constructFiles.generatedConfig.outPath;
      syncPiConfig = config.constructFiles.syncPiConfig.outPath;
    };

    constructFiles = {
      generatedConfig = {
        relPath = "${config.binName}-config/settings.json";
        output = lib.mkOverride 0 config.generatedConfig.output;
        content = builtins.toJSON config.settings;
      };

      syncPiConfig = {
        relPath = "bin/sync-pi-config";
        builder = ''mkdir -p "$(dirname "$2")" && cp "$1" "$2" && chmod +x "$2"'';
        content = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          pi_config_dir="''${PI_CODING_AGENT_DIR:-${runtimeConfigDir}}"
          settings_path="$pi_config_dir/settings.json"
          generated_settings="${config.constructFiles.generatedConfig.path}"

          ${pkgs.coreutils}/bin/mkdir -p "$pi_config_dir"

          if [[ ! -e "$settings_path" ]]; then
            ${pkgs.coreutils}/bin/install -m 0600 "$generated_settings" "$settings_path"
            exit 0
          fi

          temporary_settings="$(${pkgs.coreutils}/bin/mktemp "$pi_config_dir/.settings.json.XXXXXX")"
          trap '${pkgs.coreutils}/bin/rm -f "$temporary_settings"' EXIT

          # Keep Pi-managed values that Nix does not declare, but make the
          # generated declaration authoritative for overlapping values.
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
            "$settings_path" "$generated_settings" > "$temporary_settings"
          ${pkgs.coreutils}/bin/install -m 0600 "$temporary_settings" "$settings_path"
        '';
      };
    };

    runShell = lib.mkIf config.autoSyncConfig [
      {
        name = "SYNC_PI_CONFIG";
        data = ''${config.constructFiles.syncPiConfig.path}'';
      }
    ];

    meta.description = ''
      Wrapper module for the Pi coding agent.

      Generates JSON settings, keeps Pi's runtime state writable, and merges
      declarative settings into the runtime agent directory at startup.
    '';
  };
}
