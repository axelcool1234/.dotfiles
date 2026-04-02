{
  baseVars,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Reuse the pinned Spicetify package set so our declarative theme/bootstrap
  # files stay in sync with the Spicetify CLI and theme sources we tested.
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Comfy is the theme Noctalia's Spotify docs are written around.
  # We treat it as the stable base theme whose `color.ini` gets rewritten by
  # Noctalia whenever the active shell theme changes.
  comfyThemeSrc = spicePkgs.themes.comfy.src;

  # Raw `spicetify-cli` is strict about backup metadata. Theme refreshes only
  # need the backup metadata to *look* current; they do not need a full restore
  # + backup cycle every time. This wrapper keeps that metadata aligned with the
  # current Flatpak Spotify version before delegating to `spicetify refresh`.
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

      # Respect the same XDG locations Spicetify itself uses. This keeps the
      # wrapper compatible with both our declarative bootstrap and manual use.
      config_dir="''${SPICETIFY_CONFIG:-''${XDG_CONFIG_HOME:-$HOME/.config}/spicetify}"
      state_dir="''${SPICETIFY_STATE:-''${XDG_STATE_HOME:-$HOME/.local/state}/spicetify}"
      config_file="$config_dir/config-xpui.ini"
      raw_cli='${pkgs.spicetify-cli}/bin/spicetify'

      # Small INI reader for the handful of values we need from config-xpui.ini.
      # We intentionally keep this tiny instead of pulling in a heavier parser.
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

      # Matching INI writer. We use this only for the `Backup` section that the
      # CLI checks before allowing `refresh` on an already patched install.
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

      # Spicetify has used both config and state locations for backup files over
      # time, so probe the common directories instead of assuming only one.
      backup_exists() {
        local backup_dir

        for backup_dir in "$state_dir/Backup" "$config_dir/Backup"; do
          if [ -d "$backup_dir" ] && find "$backup_dir" -maxdepth 1 -type f -name '*.spa' | grep -q .; then
            return 0
          fi
        done

        return 1
      }

      first_command=""
      passthrough_flags=()
      trailing_args=()

      while [ "$#" -gt 0 ]; do
        case "$1" in
          -q|--quiet|-e|--extension|-a|--app|-n|--no-restart)
            passthrough_flags+=("$1")
            shift
            ;;
          --)
            shift
            break
            ;;
          -*)
            exec "$raw_cli" "$@"
            ;;
          *)
            first_command="$1"
            shift
            trailing_args=("$@")
            break
            ;;
        esac
      done

      if [ "$#" -gt 0 ] && [ -z "$first_command" ]; then
        first_command="$1"
        shift
        trailing_args=("$@")
      fi

      # The CLI compares `Backup.version` against the current Spotify version read
      # from the prefs file. When Flatpak Spotify updates independently, those can
      # drift apart and `refresh` starts refusing to run. Before we ask the raw
      # CLI to refresh theme files, make the metadata match the currently running
      # app version and CLI version.
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

      # Ask a running Spotify window to reload its frontend in place through the
      # Chromium DevTools websocket. This is the same general mechanism Spicetify
      # uses for `watch -l`, but here we call it as a one-shot after refresh.
      reload_running_spotify() {
        local debugger_url

        debugger_url="$(${pkgs.curl}/bin/curl -fsS http://localhost:9222/json/list 2>/dev/null \
          | ${pkgs.jq}/bin/jq -r '.[] | select(.url | contains("spotify")) | .webSocketDebuggerUrl' \
          | head -n1)"

        [ -n "$debugger_url" ] || return 1

        # Spotify's embedded Chromium can keep serving cached XPUI assets after
        # Spicetify rewrites them. A DevTools page reload with cache bypass is
        # much more reliable than `window.location.reload()` for hot theme swaps.
        printf '%s' '{"id":0,"method":"Page.reload","params":{"ignoreCache":true}}' \
          | ${pkgs.websocat}/bin/websocat -n1 "$debugger_url" >/dev/null 2>&1
      }

      case "$first_command" in
        apply|refresh)
          # Treat `apply` and `refresh` as the same steady-state operation:
          # update backup metadata and let the real CLI rewrite the live theme
          # files inside the already-patched Spotify install, then reload the
          # running frontend without killing playback.
          [ "''${#trailing_args[@]}" -eq 0 ] || exec "$raw_cli" "''${passthrough_flags[@]}" "$first_command" "''${trailing_args[@]}"
          sync_backup_metadata
          "$raw_cli" "''${passthrough_flags[@]}" refresh --no-restart
          reload_running_spotify || true
          ;;
        reload)
          [ "''${#trailing_args[@]}" -eq 0 ] || exec "$raw_cli" "''${passthrough_flags[@]}" reload "''${trailing_args[@]}"
          reload_running_spotify
          ;;
        "")
          exec "$raw_cli" "''${passthrough_flags[@]}"
          ;;
        *)
          # Everything else (`backup`, `restore`, `config`, etc.) should behave
          # exactly like the upstream CLI.
          exec "$raw_cli" "''${passthrough_flags[@]}" "$first_command" "''${trailing_args[@]}"
          ;;
      esac
    '';
  };

  # This file exists only to give Noctalia a guaranteed post-hook slot for an
  # extra managed Spotify refresh after theme changes.
  spicetifyRefreshTrigger = pkgs.writeText "spicetify-refresh-trigger.txt" ''
    trigger
  '';

  # These names are written into `config-xpui.ini`. Spicetify expects a pipe-
  # separated list of extension file names, not Nix package names.
  spicetifyExtensionNames = [
    spicePkgs.extensions.adblock.name
    spicePkgs.extensions.shuffle.name
    spicePkgs.extensions.keyboardShortcut.name
    spicePkgs.extensions.fullAppDisplay.name
  ];

  # Static pieces of the Comfy theme can remain declarative. The one mutable
  # file is `color.ini`, which Noctalia rewrites as themes change.
  homeFiles = {
    "spicetify/Themes/Comfy/app.css" = "${comfyThemeSrc}/app.css";
    "spicetify/Themes/Comfy/theme.js" = "${comfyThemeSrc}/theme.js";
    "spicetify/Themes/Comfy/theme.script.js" = "${comfyThemeSrc}/theme.script.js";
    "spicetify/Themes/Comfy/user.css" = "${comfyThemeSrc}/user.css";

    # Keep extensions declarative too. Spicetify only needs them to exist in
    # the config directory; it copies them into Spotify when patching.
    "spicetify/Extensions/${spicePkgs.extensions.adblock.name}" =
      "${spicePkgs.extensions.adblock.src}/${spicePkgs.extensions.adblock.name}";
    "spicetify/Extensions/${spicePkgs.extensions.shuffle.name}" =
      "${spicePkgs.extensions.shuffle.src}/${spicePkgs.extensions.shuffle.name}";
    "spicetify/Extensions/${spicePkgs.extensions.keyboardShortcut.name}" =
      "${spicePkgs.extensions.keyboardShortcut.src}/${spicePkgs.extensions.keyboardShortcut.name}";
    "spicetify/Extensions/${spicePkgs.extensions.fullAppDisplay.name}" =
      "${spicePkgs.extensions.fullAppDisplay.src}/${spicePkgs.extensions.fullAppDisplay.name}";
  };

  # Keep an explicit user-template hook as a belt-and-suspenders refresh path.
  userTemplates = {
    templates.spicetify-refresh = {
      input_path = spicetifyRefreshTrigger;
      output_path = "~/.cache/noctalia/spicetify-refresh-trigger.txt";
      post_hook = "${spicetifyManaged}/bin/spicetify refresh || true";
    };
  };

  # Flatpak install + Spicetify repair/bootstrap happen here.
  userService = {
    description = "Install Spotify Flatpak for Noctalia";
    wantedBy = [ "default.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      config_dir="$HOME/.config/spicetify"
      config_file="$config_dir/config-xpui.ini"
      raw_spicetify='${pkgs.spicetify-cli}/bin/spicetify'

      prepare_flatpak_user_exports() {
        local exports_dir hicolor_dir

        exports_dir="$HOME/.local/share/flatpak/exports"
        hicolor_dir="$exports_dir/share/icons/hicolor"

        mkdir -p "$hicolor_dir"

        # Flatpak sometimes leaves read-only export files behind. Later install
        # runs then fail while trying to refresh those exports, which can leave
        # the app half-installed or missing entirely.
        find "$exports_dir" -type f ! -writable -exec chmod u+w {} + 2>/dev/null || true
      }

      reinstall_flatpak_spotify() {
        prepare_flatpak_user_exports
        ${pkgs.flatpak}/bin/flatpak uninstall --user --noninteractive -y com.spotify.Client >/dev/null 2>&1 || true
        ${pkgs.flatpak}/bin/flatpak install --user --noninteractive -y flathub com.spotify.Client
      }

      backup_exists() {
        local backup_dir

        for backup_dir in \
          "$config_dir/Backup" \
          "''${XDG_STATE_HOME:-$HOME/.local/state}/spicetify/Backup"
        do
          if [ -d "$backup_dir" ] && find "$backup_dir" -maxdepth 1 -type f -name '*.spa' | grep -q .; then
            return 0
          fi
        done

        return 1
      }

      spotify_install_patched() {
        [ -f "$spotify_path/Apps/xpui/helper/spicetifyWrapper.js" ]
      }

      spicetify_bootstrap_ready() {
        backup_exists && spotify_install_patched
      }

      resolve_spotify_path() {
        flatpak_root="$(${pkgs.flatpak}/bin/flatpak info --user --show-location com.spotify.Client)"

        if [ -d "$flatpak_root/files/extra/share/spotify" ]; then
          spotify_path="$flatpak_root/files/extra/share/spotify"
        elif [ -d "$flatpak_root/active/files/extra/share/spotify" ]; then
          spotify_path="$flatpak_root/active/files/extra/share/spotify"
        else
          echo "Could not determine Flatpak Spotify app path" >&2
          exit 1
        fi
      }

      write_spicetify_config() {
        cat > "$config_file" <<EOF
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
      }

      # Ensure the repository exists before trying to install the app.
      ${pkgs.flatpak}/bin/flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo

      prepare_flatpak_user_exports

      # Install Spotify only if it is not already present in the user's Flatpak
      # profile.
      if ! ${pkgs.flatpak}/bin/flatpak info --user com.spotify.Client >/dev/null 2>&1; then
        ${pkgs.flatpak}/bin/flatpak install --user --noninteractive -y flathub com.spotify.Client
      fi

      # Flatpak app layouts can vary a little. Probe the common locations and
      # stop with a useful error if neither exists.
      resolve_spotify_path

      # Spicetify reads the current Spotify version from the prefs file.
      # Create the directory and empty file up front so the CLI has something
      # stable to point at on first boot.
      prefs_path="$HOME/.var/app/com.spotify.Client/config/spotify/prefs"
      mkdir -p "$(dirname "$prefs_path")" "$config_dir/Themes/Comfy"
      touch "$prefs_path"

      # `watch -l` expects `assets/` to be a real directory tree. A symlinked
      # Hjem directory confused the watcher, so copy it here during bootstrap.
      rm -rf "$config_dir/Themes/Comfy/assets"
      mkdir -p "$config_dir/Themes/Comfy/assets"
      cp -r "${comfyThemeSrc}/assets/." "$config_dir/Themes/Comfy/assets/"

      # Seed the mutable color file once, then leave it writable so Noctalia's
      # built-in Spicetify template can rewrite it later.
      if [ ! -e "$config_dir/Themes/Comfy/color.ini" ]; then
        cp "${comfyThemeSrc}/color.ini" "$config_dir/Themes/Comfy/color.ini"
      fi
      chmod u+w "$config_dir/Themes/Comfy/color.ini"

      # Write the active Spicetify config each time so it always points at the
      # current Flatpak install path and current extension list.
      write_spicetify_config

      # Keep the current Flatpak deployment patched and backed up. We cannot
      # trust a stale marker file here because an earlier failed bootstrap can
      # leave Spotify customized without any valid backup state, which then
      # breaks later theme refreshes.
      if ! spicetify_bootstrap_ready; then
        if ! ${pkgs.flatpak}/bin/flatpak info --user com.spotify.Client >/dev/null 2>&1; then
          reinstall_flatpak_spotify
        elif spotify_install_patched && ! backup_exists; then
          # The app is already patched but the backup disappeared, usually
          # because the state dir was wiped. Reset the Flatpak app image back to
          # pristine files so Spicetify can produce a fresh backup again.
          reinstall_flatpak_spotify
        fi

        resolve_spotify_path
        write_spicetify_config
        "$raw_spicetify" backup apply
      fi

      if ! spicetify_bootstrap_ready; then
        echo "Spicetify bootstrap did not produce a usable backup state" >&2
        exit 1
      fi
    '';
  };

  # Packages this program-specific integration needs in the user environment.
  packages = [ spicetifyManaged ];

  # Under Noctalia, Spotify is the Flatpak app plus its user-scoped container.
  # Persist those homes here, alongside the rest of the Spotify integration.
  persistHomeDirectories = [
    ".local/share/flatpak"
    ".local/state/spicetify"
    ".var/app/com.spotify.Client"
  ];

  # This program needs a mutable install target, so enable Flatpak here rather
  # than globally for every shell configuration.
  enableFlatpak = true;

  # Flatpak desktop apps need a portal backend. GTK is the simplest generic
  # choice for this Niri-based setup.
  portalConfig = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = lib.mkDefault "*";
  };
in
{
  inherit
    enableFlatpak
    homeFiles
    packages
    persistHomeDirectories
    portalConfig
    userService
    userTemplates
    ;
}
