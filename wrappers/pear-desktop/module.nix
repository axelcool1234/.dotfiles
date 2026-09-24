{
  config,
  lib,
  pkgs,
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
        Pear Desktop settings merged into its writable `config.json`.

        Wrapper-managed values take precedence while settings not declared here
        remain available for Pear Desktop to manage interactively.
      '';
    };

    themes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "noctalia.css" ];
      description = ''
        CSS theme files loaded by Pear Desktop. Relative paths are resolved
        beneath `outOfStoreConfig`; absolute paths are used unchanged.
      '';
    };

    outOfStoreConfig = lib.mkOption {
      type = lib.types.str;
      default = "${"$"}{XDG_CONFIG_HOME:-${"$"}HOME/.config}/YouTube Music";
      description = ''
        Writable Pear Desktop user-data directory. The wrapper synchronizes
        declared settings into this directory before Pear Desktop starts.
      '';
    };

    autoSyncConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to merge the generated settings into Pear Desktop's writable
        configuration each time the wrapper starts.
      '';
    };

    liveThemeReload = {
      enable = lib.mkEnableOption "live reloading of Pear Desktop CSS themes";

      debuggingPort = lib.mkOption {
        type = lib.types.port;
        default = 9222;
        description = ''
          Local Chromium debugging port used by the generated theme reload
          helper to update Pear Desktop without restarting playback.
        '';
      };
    };

    generatedConfig.output = lib.mkOption {
      type = lib.types.str;
      default = config.outputName;
      description = "The derivation output for the generated Pear Desktop configuration.";
    };
  };

  config = {
    package = lib.mkDefault pkgs.pear-desktop;

    passthru = {
      generatedConfig = config.constructFiles.generatedConfig.outPath;
      syncPearDesktopConfig = config.constructFiles.syncPearDesktopConfig.outPath;
    }
    // lib.optionalAttrs config.liveThemeReload.enable {
      reloadPearDesktopTheme = config.constructFiles.reloadPearDesktopTheme.outPath;
    };

    addFlag = lib.mkIf config.liveThemeReload.enable [
      "--remote-debugging-port=${toString config.liveThemeReload.debuggingPort}"
      "--remote-allow-origins=http://127.0.0.1:${toString config.liveThemeReload.debuggingPort}"
    ];

    constructFiles = {
      generatedConfig = {
        relPath = "${config.binName}-config/config.json";
        output = lib.mkOverride 0 config.generatedConfig.output;
        content = builtins.toJSON config.settings;
      };

      generatedThemes = {
        relPath = "${config.binName}-config/themes.json";
        output = lib.mkOverride 0 config.generatedConfig.output;
        content = builtins.toJSON config.themes;
      };

      syncPearDesktopConfig = {
        relPath = "bin/sync-pear-desktop-config";
        builder = ''mkdir -p "$(dirname "$2")" && cp "$1" "$2" && chmod +x "$2"'';
        content = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          config_dir="${runtimeConfigDir}"
          settings_path="$config_dir/config.json"
          generated_settings="${config.constructFiles.generatedConfig.path}"
          generated_themes="${config.constructFiles.generatedThemes.path}"

          ${pkgs.coreutils}/bin/mkdir -p "$config_dir"

          temporary_settings="$(${pkgs.coreutils}/bin/mktemp "$config_dir/.config.json.XXXXXX")"
          temporary_themed="$temporary_settings.themed"
          trap '${pkgs.coreutils}/bin/rm -f "$temporary_settings" "$temporary_themed"' EXIT

          if [[ -e "$settings_path" ]]; then
            # Preserve Pear-managed values while making declared values
            # authoritative wherever the two configurations overlap.
            ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
              "$settings_path" "$generated_settings" > "$temporary_settings"
          else
            ${pkgs.coreutils}/bin/cp "$generated_settings" "$temporary_settings"
          fi

          # Pear expects absolute CSS paths. Resolve wrapper theme paths only at
          # runtime so this also works through `nix run` for another user.
          ${pkgs.jq}/bin/jq \
            --arg config_dir "$config_dir" \
            --slurpfile themes "$generated_themes" \
            '.options.themes = ($themes[0] | map(
              if startswith("/") then . else $config_dir + "/" + . end
            ))' \
            "$temporary_settings" > "$temporary_themed"

          ${pkgs.coreutils}/bin/install -m 0600 \
            "$temporary_themed" "$settings_path"
        '';
      };

      reloadPearDesktopTheme = lib.mkIf config.liveThemeReload.enable {
        relPath = "bin/reload-pear-desktop-theme";
        builder = ''mkdir -p "$(dirname "$2")" && cp "$1" "$2" && chmod +x "$2"'';
        content = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          theme_path="''${1:-}"
          if [[ -z "$theme_path" || ! -r "$theme_path" ]]; then
            exit 0
          fi

          targets="$(${pkgs.curl}/bin/curl \
            --silent \
            --fail \
            --max-time 1 \
            http://127.0.0.1:${toString config.liveThemeReload.debuggingPort}/json/list \
            2>/dev/null || true)"

          debugger_url="$(${pkgs.jq}/bin/jq -r '
            first(
              .[]
              | select(
                  .type == "page"
                  and ((.url // "") | contains("music.youtube.com"))
                )
              | .webSocketDebuggerUrl
            ) // empty
          ' <<< "$targets")"

          if [[ -z "$debugger_url" ]]; then
            exit 0
          fi

          message="$(${pkgs.jq}/bin/jq -cn --rawfile css "$theme_path" '
            {
              id: 1,
              method: "Runtime.evaluate",
              params: {
                expression: (
                  "(() => {"
                  + "const id = " + ("noctalia-live-theme" | tojson) + ";"
                  + "let style = document.getElementById(id);"
                  + "if (!style) {"
                  + "style = document.createElement(" + ("style" | tojson) + ");"
                  + "style.id = id;"
                  + "(document.head || document.documentElement).appendChild(style);"
                  + "}"
                  + "style.textContent = " + ($css | tojson) + ";"
                  + "})()"
                ),
                returnByValue: true
              }
            }
          ')"

          printf '%s\n' "$message" \
            | ${pkgs.websocat}/bin/websocat \
              -n1 \
              --origin=http://127.0.0.1:${toString config.liveThemeReload.debuggingPort} \
              "$debugger_url" >/dev/null 2>&1
        '';
      };
    };

    runShell = lib.mkIf config.autoSyncConfig [
      {
        name = "SYNC_PEAR_DESKTOP_CONFIG";
        data = "${config.constructFiles.syncPearDesktopConfig.path}";
      }
    ];

    meta.description = ''
      Wrapper module for Pear Desktop.

      Generates JSON settings, keeps Electron's runtime state writable, and
      merges declarative settings into the runtime configuration at startup.
    '';
  };
}
