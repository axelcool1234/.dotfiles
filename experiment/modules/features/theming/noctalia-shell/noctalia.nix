{
  config,
  baseVars,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  comfyThemeSrc = spicePkgs.themes.comfy.src;
  spicetifyManaged = pkgs.writeShellApplication {
    name = "spicetify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.gnused
      pkgs.jq
      pkgs.spicetify-cli
      pkgs.websocat
    ];
    text = ''
      set -euo pipefail

      config_dir="''${SPICETIFY_CONFIG:-''${XDG_CONFIG_HOME:-$HOME/.config}/spicetify}"
      state_dir="''${SPICETIFY_STATE:-''${XDG_STATE_HOME:-$HOME/.local/state}/spicetify}"
      config_file="$config_dir/config-xpui.ini"
      backup_dir="$state_dir/Backup"
      raw_cli='${pkgs.spicetify-cli}/bin/spicetify'

      get_ini_value() {
        local section="$1"
        local key="$2"

        awk -F '=' -v section="$section" -v key="$key" '
          BEGIN { in_section = 0 }
          /^\[/ {
            in_section = ($0 == "[" section "]")
            next
          }
          in_section {
            current = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", current)
            if (current == key) {
              value = substr($0, index($0, "=") + 1)
              gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
              print value
              exit
            }
          }
        ' "$config_file"
      }

      set_ini_value() {
        local section="$1"
        local key="$2"
        local value="$3"
        local tmp

        tmp=$(mktemp)

        awk -v section="$section" -v key="$key" -v value="$value" '
          BEGIN {
            in_section = 0
            section_seen = 0
            key_written = 0
          }
          function flush_key_if_needed() {
            if (in_section && !key_written) {
              print key " = " value
              key_written = 1
            }
          }
          /^\[/ {
            flush_key_if_needed()
            in_section = ($0 == "[" section "]")
            if (in_section) {
              section_seen = 1
            }
            print
            next
          }
          {
            if (in_section) {
              split($0, parts, "=")
              current = parts[1]
              gsub(/^[[:space:]]+|[[:space:]]+$/, "", current)
              if (current == key) {
                print key " = " value
                key_written = 1
                next
              }
            }
            print
          }
          END {
            flush_key_if_needed()
            if (!section_seen) {
              print ""
              print "[" section "]"
              print key " = " value
            }
          }
        ' "$config_file" > "$tmp"

        mv "$tmp" "$config_file"
      }

      backup_exists() {
        [ -d "$backup_dir" ] && find "$backup_dir" -maxdepth 1 -type f -name '*.spa' | grep -q .
      }

      sync_backup_metadata() {
        local prefs_path current_version cli_version

        [ -f "$config_file" ] || return 0
        backup_exists || return 0

        prefs_path="$(get_ini_value Setting prefs_path)"
        [ -n "$prefs_path" ] || return 0
        [ -f "$prefs_path" ] || return 0

        current_version="$(awk -F '=' '/^app\.last-launched-version[[:space:]]*=/{value=substr($0, index($0, "=") + 1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); print value; exit}' "$prefs_path")"
        [ -n "$current_version" ] || return 0

        cli_version="$($raw_cli -v)"

        set_ini_value Backup version "$current_version"
        set_ini_value Backup with "$cli_version"
      }

      reload_running_spotify() {
        local debugger_url

        debugger_url="$(${pkgs.curl}/bin/curl -fsS http://localhost:9222/json/list 2>/dev/null \
          | ${pkgs.jq}/bin/jq -r '.[] | select(.url | contains("spotify")) | .webSocketDebuggerUrl' \
          | head -n1)"

        [ -n "$debugger_url" ] || return 1

        printf '%s' '{"id":0,"method":"Runtime.evaluate","params":{"expression":"window.location.reload()"}}' \
          | ${pkgs.websocat}/bin/websocat -n1 "$debugger_url" >/dev/null 2>&1
      }

      case "''${1:-}" in
        apply|refresh)
          sync_backup_metadata
          "$raw_cli" refresh --no-restart
          reload_running_spotify || true
          ;;
        reload)
          reload_running_spotify
          ;;
        *)
          exec "$raw_cli" "$@"
          ;;
      esac
    '';
  };
  spicetifyRefreshTrigger = pkgs.writeText "spicetify-refresh-trigger.txt" ''
    trigger
  '';
  onekoExtension = {
    src = pkgs.fetchFromGitHub {
      owner = "kyrie25";
      repo = "spicetify-oneko";
      rev = "589a8cc3a3939b8c9fc4f2bd087ed433e9af5002";
      hash = "sha256-lestrf4sSwGbBqy+0J7u5IoU6xNKHh35IKZxt/phpNY=";
    };
    name = "oneko.js";
  };

  pywalfoxTriggerTemplate = pkgs.writeText "pywalfox-trigger.css" ''
    /* No-op template used only to trigger pywalfox update via Noctalia post_hook. */
  '';

  nvimBase16Template = pkgs.writeText "nvim-base16-template.lua" ''
    return {
      base00 = '{{colors.surface.default.hex}}',
      base01 = '{{colors.surface_container.default.hex}}',
      base02 = '{{colors.surface_container_high.default.hex}}',
      base03 = '{{colors.outline.default.hex}}',
      base04 = '{{colors.on_surface_variant.default.hex}}',
      base05 = '{{colors.on_surface.default.hex}}',
      base06 = '{{colors.on_surface.default.hex}}',
      base07 = '{{colors.on_background.default.hex}}',
      base08 = '{{colors.error.default.hex}}',
      base09 = '{{colors.tertiary.default.hex}}',
      base0A = '{{colors.secondary.default.hex}}',
      base0B = '{{colors.primary.default.hex}}',
      base0C = '{{colors.tertiary_fixed_dim.default.hex}}',
      base0D = '{{colors.primary_fixed_dim.default.hex}}',
      base0E = '{{colors.secondary_fixed_dim.default.hex}}',
      base0F = '{{colors.error_container.default.hex}}',
    }
  '';

  noctaliaUserTemplates = (pkgs.formats.toml { }).generate "noctalia-user-templates.toml" {
    config = { };
    # Firefox
    templates.pywalfox = {
      input_path = pywalfoxTriggerTemplate;
      output_path = "~/.cache/noctalia/pywalfox-trigger.css";
      post_hook = "${pkgs.pywalfox-native}/bin/pywalfox update";
    };
    # Neovim
    templates.nvim-base16 = {
      input_path = nvimBase16Template;
      output_path = "~/.cache/noctalia/nvim-base16.lua";
      post_hook = "pkill -SIGUSR1 -x nvim || true";
    };
    # Spotify / Spicetify
    # Let Noctalia's built-in Spicetify template own `Comfy/color.ini` and use a
    # no-op user template only to trigger the refresh hook afterwards.
    templates.spicetify-refresh = {
      input_path = spicetifyRefreshTrigger;
      output_path = "~/.cache/noctalia/spicetify-refresh-trigger.txt";
      post_hook = "${spicetifyManaged}/bin/spicetify refresh || true";
    };
  };

  spicetifyExtensionNames = [
    spicePkgs.extensions.adblock.name
    spicePkgs.extensions.shuffle.name
    spicePkgs.extensions.keyboardShortcut.name
    spicePkgs.extensions.fullAppDisplay.name
    onekoExtension.name
  ];
in
{
  config = lib.mkIf (config.preferences.desktop-shell == "noctalia-shell") {
    services.flatpak.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = lib.mkDefault "*";
    };

    environment.systemPackages = [
      spicetifyManaged
    ];

    hjem.users.${baseVars.username} = {
      enable = true;
      clobberFiles = true;

      xdg.config.files."spicetify/Themes/Comfy/app.css".source = "${comfyThemeSrc}/app.css";
      xdg.config.files."spicetify/Themes/Comfy/assets".source = "${comfyThemeSrc}/assets";
      xdg.config.files."spicetify/Themes/Comfy/theme.js".source = "${comfyThemeSrc}/theme.js";
      xdg.config.files."spicetify/Themes/Comfy/theme.script.js".source = "${comfyThemeSrc}/theme.script.js";
      xdg.config.files."spicetify/Themes/Comfy/user.css".source = "${comfyThemeSrc}/user.css";

      xdg.config.files."spicetify/Extensions/${spicePkgs.extensions.adblock.name}".source =
        "${spicePkgs.extensions.adblock.src}/${spicePkgs.extensions.adblock.name}";
      xdg.config.files."spicetify/Extensions/${spicePkgs.extensions.shuffle.name}".source =
        "${spicePkgs.extensions.shuffle.src}/${spicePkgs.extensions.shuffle.name}";
      xdg.config.files."spicetify/Extensions/${spicePkgs.extensions.keyboardShortcut.name}".source =
        "${spicePkgs.extensions.keyboardShortcut.src}/${spicePkgs.extensions.keyboardShortcut.name}";
      xdg.config.files."spicetify/Extensions/${spicePkgs.extensions.fullAppDisplay.name}".source =
        "${spicePkgs.extensions.fullAppDisplay.src}/${spicePkgs.extensions.fullAppDisplay.name}";
      xdg.config.files."spicetify/Extensions/${onekoExtension.name}".source =
        "${onekoExtension.src}/${onekoExtension.name}";

      xdg.config.files."noctalia/user-templates.toml".source = noctaliaUserTemplates;
    };

    systemd.user.services.spotify-flatpak-bootstrap = {
      description = "Install Spotify Flatpak for Noctalia";
      wantedBy = [ "default.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        marker="$HOME/.config/spicetify/.flatpak-bootstrap-complete"

        ${pkgs.flatpak}/bin/flatpak remote-add --user --if-not-exists flathub \
          https://flathub.org/repo/flathub.flatpakrepo

        if ! ${pkgs.flatpak}/bin/flatpak info --user com.spotify.Client >/dev/null 2>&1; then
          ${pkgs.flatpak}/bin/flatpak install --user --noninteractive -y flathub com.spotify.Client
        fi

        flatpak_root="$(${pkgs.flatpak}/bin/flatpak info --user --show-location com.spotify.Client)"

        if [ -d "$flatpak_root/files/extra/share/spotify" ]; then
          spotify_path="$flatpak_root/files/extra/share/spotify"
        elif [ -d "$flatpak_root/active/files/extra/share/spotify" ]; then
          spotify_path="$flatpak_root/active/files/extra/share/spotify"
        else
          echo "Could not determine Flatpak Spotify app path" >&2
          exit 1
        fi

        prefs_path="$HOME/.var/app/com.spotify.Client/config/spotify/prefs"
        mkdir -p "$(dirname "$prefs_path")" "$HOME/.config/spicetify/Themes/Comfy"
        touch "$prefs_path"

        if [ ! -e "$HOME/.config/spicetify/Themes/Comfy/color.ini" ]; then
          cp "${comfyThemeSrc}/color.ini" "$HOME/.config/spicetify/Themes/Comfy/color.ini"
        fi
        chmod u+w "$HOME/.config/spicetify/Themes/Comfy/color.ini"

        cat > "$HOME/.config/spicetify/config-xpui.ini" <<EOF
[Setting]
spotify_path           = $spotify_path
prefs_path             = $prefs_path
current_theme          = Comfy
color_scheme           = Comfy
inject_css             = 1
replace_colors         = 1
overwrite_assets       = 1
inject_theme_js        = 1
check_spicetify_update = 0

[Preprocesses]
disable_ui_logging = 1
remove_rtl_rule    = 1
expose_apis        = 1
disable_sentry     = 1

[AdditionalOptions]
extensions            = ${lib.concatStringsSep "|" spicetifyExtensionNames}
custom_apps           =
sidebar_config        = 0
home_config           = 1
experimental_features = 1
EOF

        if [ ! -e "$marker" ]; then
          ${spicetifyManaged}/bin/spicetify backup apply || true
          touch "$marker"
        fi
      '';
    };
  };
}
