{
  hostVars,
  inputs,
  lib,
  pkgs,
  selfPkgs,
  system,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktopShell == "noctalia";

  # Region Recorder's Noctalia 5.1-compatible release passes codec family
  # names to wf-recorder, while wf-recorder expects concrete FFmpeg encoder
  # names. Keep the community plugin unchanged and translate at its boundary.
  wfRecorderCompat = pkgs.writeShellApplication {
    name = "wf-recorder";
    text = ''
      args=("$@")

      for ((index = 0; index < ''${#args[@]}; index++)); do
        if [[ ''${args[index]} == "-c" || ''${args[index]} == "--codec" ]] \
          && ((index + 1 < ''${#args[@]})); then
          case ''${args[index + 1]} in
            h264) args[index + 1]="libx264" ;;
            hevc) args[index + 1]="libx265" ;;
            av1) args[index + 1]="libaom-av1" ;;
          esac
        fi
      done

      exec ${lib.getExe pkgs.wf-recorder} "''${args[@]}"
    '';
  };

  # Runtime tools used by Noctalia's theme-template hooks rather than by an
  # individual plugin.
  templateRuntimePkgs = with pkgs; [
    bash
    coreutils
    dbus
    diffutils
    gawk
    glib
    gnugrep
    gnused
    jq
    procps
  ];

  # The community Spicetify template invokes `spicetify` in its post-hook.
  # Pull in the selected wrapper only when Spotify is the configured player;
  # that wrapper carries both the launcher and its managed CLI variant.
  spicetifyTemplateRuntimePkgs = lib.optionals (hostVars.music == "spicetify") [
    selfPkgs.spicetify
  ];

  bitwardenPluginRuntimePkgs = with pkgs; [
    bitwarden-cli
  ];

  # Cursor can list and apply existing themes with Python alone. Wand,
  # win2xcur, ImageMagick, and Zenity enable previews, imports, builds, and
  # graphical folder selection.
  cursorPluginRuntimePkgs = with pkgs; [
    imagemagick
    win2xcur
    zenity
    (python3.withPackages (pythonPackages: [
      pythonPackages.wand
      win2xcur
    ]))
  ];

  colorPickerPluginRuntimePkgs = with pkgs; [
    hyprpicker
  ];

  ocrPluginRuntimePkgs = with pkgs; [
    grim
    slurp
    tesseract
  ];

  # Prefer the known-good wf-recorder path on Fermi. The compatibility wrapper
  # also translates Region Recorder's codec-family names to FFmpeg encoders.
  regionRecorderPluginRuntimePkgs = with pkgs; [
    ffmpeg
    slurp
    wfRecorderCompat
  ];

  # Screen Toolkit is intentionally complete enough for every local tool while
  # preferring Fermi's known-good wf-recorder path. Satty satisfies annotation,
  # and wf-recorder avoids the broken NVK gpu-screen-recorder path.
  screenToolkitPluginRuntimePkgs = with pkgs; [
    bc
    coreutils
    curl
    ffmpeg
    grim
    hyprpicker
    imagemagick
    jq
    mpv
    niri
    procps
    pulseaudio
    satty
    slurp
    tesseract
    translate-shell
    wfRecorderCompat
    xdg-utils
    zbar
  ];

  # Wallhaven uses Noctalia's own HTTP and image APIs and has no external
  # executable dependencies.
  wallhavenPluginRuntimePkgs = [ ];

  userTemplates = {
    discord-midnight-vesktop = {
      input_path = "${inputs.noctalia-templates}/discord/discord-midnight.css";
      output_path = "$XDG_CONFIG_HOME/vesktop/themes/noctalia.theme.css";
    };
    # The community template owns Pear's CSS and config update. This companion
    # entry runs afterwards solely to inject the new CSS into an open window.
    pear-desktop-live-reload = {
      input_path = "${inputs.noctalia-templates}/pear-desktop/pearColors.css";
      post_hook = ''
        ${selfPkgs.pear-desktop.passthru.reloadPearDesktopTheme} \
          "''${XDG_CONFIG_HOME:-$HOME/.config}/YouTube Music/noctalia.css" || true
      '';
      hook_async = false;
    };
    yazi = {
      input_path = "${inputs.noctalia-templates}/yazi/yazi.toml";
      output_path = "$XDG_CONFIG_HOME/yazi/flavors/noctalia.yazi/flavor.toml";
      post_hook = "bash ${inputs.noctalia-templates}/yazi/apply.sh";
    };
    yazi-syntax = {
      input_path = "${inputs.noctalia-templates}/yazi/yazi.tmTheme";
      output_path = "$XDG_CONFIG_HOME/yazi/flavors/noctalia.yazi/tmtheme.xml";
    };
    zathura = {
      input_path = "${inputs.noctalia-templates}/zathura/zathurarc";
      output_path = "$XDG_CONFIG_HOME/zathura/noctaliarc";
      post_hook = "bash ${inputs.noctalia-templates}/zathura/apply.sh";
    };
  }
  // lib.optionalAttrs (hostVars.music == "spicetify") {
    spicetify = {
      input_path = "${inputs.noctalia-templates}/spicetify/spicetify.ini";
      output_path = "$XDG_CONFIG_HOME/spicetify/Themes/Comfy/color.ini";
      post_hook = "bash ${inputs.noctalia-templates}/spicetify/apply.sh";
      hook_async = false;
    };
  };

  builtinTemplateIds = [
    "btop"
    "gtk3"
    "gtk4"
    "helix"
    "kitty"
    "qt"
  ]
  ++ lib.optional (hostVars.compositor == "niri") "niri";

in
{
  imports = [ ./module.nix ];

  config = {
    package = inputs.noctalia.packages.${system}.default;

    # Terminal=true desktop entries should use the configured wrapped terminal,
    # not whichever unwrapped emulator happens to appear first on PATH.
    env.TERMINAL = lib.getExe selfPkgs.${hostVars.terminal};

    # Keep dependencies beside the consumer that requires them. Concatenation
    # intentionally preserves duplicate derivations when plugins share tools;
    # the wrapper environment handles those repeated inputs.
    runtimePkgs = lib.concatLists [
      templateRuntimePkgs
      spicetifyTemplateRuntimePkgs
      bitwardenPluginRuntimePkgs
      cursorPluginRuntimePkgs
      colorPickerPluginRuntimePkgs
      ocrPluginRuntimePkgs
      regionRecorderPluginRuntimePkgs
      screenToolkitPluginRuntimePkgs
      wallhavenPluginRuntimePkgs
    ];

    passthru.persist = {
      # v5 deliberately keeps declarative config and mutable state separate.
      # Persist GUI overrides, selected wallpaper, plugin state/catalogs, and
      # any local plugins without making the immutable base config writable.
      homeDirectories = [
        # The Bitwarden plugin reuses the official CLI's login and vault state.
        ".config/Bitwarden CLI"
        ".local/share/noctalia"
        ".local/state/noctalia"
      ];
      homeFiles = [ ];
    };

    passthru.desktopShell.actions = {
      launcherToggle = [
        "msg"
        "panel-toggle"
        "launcher"
      ];
      wallpaperToggle = [
        "msg"
        "panel-toggle"
        "wallpaper"
      ];
      wallhavenToggle = [
        "msg"
        "panel-toggle"
        "noctalia/wallhaven:browser"
      ];
      colorPickerPick = [
        "msg"
        "plugin"
        "oldirtty/color_picker:service"
        "all"
        "pick"
      ];
      ocrRegion = [
        "msg"
        "plugin"
        "fel/ocr:ocr"
        "all"
        "ocr-region"
      ];
      cursorManagerToggle = [
        "msg"
        "panel-toggle"
        "vn1k/cursor:manager"
      ];
      screenToolkitToggle = [
        "msg"
        "plugin"
        "alexander/screen-toolkit:service"
        "all"
        "toggle"
      ];
      sessionMenuToggle = [
        "msg"
        "panel-toggle"
        "session"
      ];
      lock = [
        "msg"
        "session"
        "lock"
      ];
      volumeIncrease = [
        "msg"
        "volume-up"
      ];
      volumeDecrease = [
        "msg"
        "volume-down"
      ];
      volumeMuteOutput = [
        "msg"
        "volume-mute"
      ];
      volumeMuteInput = [
        "msg"
        "mic-mute"
      ];
      brightnessIncrease = [
        "msg"
        "brightness-up"
      ];
      brightnessDecrease = [
        "msg"
        "brightness-down"
      ];
      screenshotRegion = [
        "msg"
        "screenshot-region"
      ];
      screenRecordToggle = [
        "msg"
        "plugin"
        "h-jangra/region-recorder:service"
        "all"
        "toggle"
      ];
    };

    settings = {
      shell = {
        font_family = hostVars.fonts.ui.family;
        time_format = "{:%-I:%M %p}";
        telemetry_enabled = false;
        clipboard_enabled = true;
        clipboard_history_max_entries = 100;
        clipboard_keep_from_closed_apps = true;
        launch_apps_as_systemd_services = hostVars.isNixosHost;
        password_style = "random";
        app_icon_colorize = true;
        app_icon_color = "secondary";

        # Match v4's visual screen-corner radius. These are decorative black
        # cutouts, distinct from pointer-triggered hot corners.
        screen_corners = {
          enabled = true;
          size = 20;
        };

        screenshot = {
          save_to_file = true;
          copy_to_clipboard = true;
          freeze_screen = true;
          close_on_copy = true;
        };

        panel = {
          launcher_placement = "floating";
          clipboard_placement = "floating";
          launcher_position = "center";
          clipboard_position = "center";
        };

        launcher = {
          categories = true;
          show_icons = true;
          compact = false;
          app_grid = true;
          sort_by_usage = true;
        };

        session = {
          grid = true;
          grid_columns = 3;
        };
      };

      wallpaper = {
        enabled = true;
        directory = "~/Pictures/Wallpapers";
        transition = [
          "fade"
          "wipe"
          "disc"
          "stripes"
          "zoom"
          "honeycomb"
        ];
        transition_duration = 1500;
        automation.enabled = false;
      };

      # v4's brightness widget applied changes to every display. In v5 this
      # behavior belongs to the brightness service rather than the widget.
      brightness.sync_all_monitors = true;

      theme = lib.mkIf useNoctaliaTheme {
        mode = "dark";
        source = "builtin";

        templates = {
          enable_builtin_templates = true;
          builtin_ids = builtinTemplateIds;
          enable_community_templates = true;
          community_ids = [
            "codex"
            "neovim"
            "pear-desktop"
            "pi-agent"
            "pywalfox-beta4"
          ];
          user = userTemplates;
        };
      };

      notification = {
        enable_daemon = true;
        position = "top_right";
        background_opacity = 0.93;
      };

      osd = {
        position = "top_right";
        background_opacity = 0.93;
      };

      lockscreen = {
        enabled = true;
        lock_before_suspend = true;
        blur_intensity = 0.5;
        tint_intensity = 0.25;
      };

      bar.main = {
        position = "top";
        # Match v4's horizontal "spacious" density. Its 47 px bar used
        # capsules at 65% of the available thickness (about 31 px).
        thickness = 47;
        background_opacity = 0.93;
        radius = 12;
        # A docked top bar should meet both upper screen corners exactly;
        # rounding them exposes small wedges of wallpaper.
        radius_top_left = 0;
        radius_top_right = 0;
        concave_edge_corners = true;
        margin_ends = 0;
        margin_edge = 0;
        padding = 0;
        widget_spacing = 3;
        capsule = true;
        capsule_thickness = 0.65;
        start = [
          "workspaces"
          "taskbar"
          "tray"
          "group:media"
        ];
        center = [ "clock" ];
        end = [
          "cpu"
          "cpu-temp"
          "memory"
          "disk"
          "output-volume"
          "input-volume"
          "brightness"
          "battery"
          "bluetooth"
          "network"
          "session"
        ];
        # v5 split v4's embedded MediaMini visualizer into its own widget.
        # Keep both pieces in one capsule so they still read as one control.
        capsule_group = [
          {
            id = "media";
            members = [
              "media"
              "media-visualizer"
            ];
            widget_spacing = 0;
          }
        ];
      };

      widget = {
        workspaces = {
          style = "regular";
          max_label_chars = 2;
          labels_only_when_occupied = true;
          # v4 sized these from the 31 px spacious capsule: 31 * 0.7 ≈ 21 px.
          # v5 starts from a fixed 16 px glyph, so scale the whole widget to
          # recover the old pill geometry while keeping its label proportional.
          scale = 1.3;
          pill_scale = 1.0;
          font_scale = 0.9;
          font_family = hostVars.fonts.monospace.family;
          font_weight = 700;
        };
        taskbar = {
          only_active_workspace = true;
          icon_scale = 0.8;
        };
        tray = {
          hide_passive = false;
          drawer = true;
          icon_color = "secondary";
        };
        media = {
          artist_first = true;
          max_length = 200;
          title_scroll = "on_hover";
          color = "secondary";
        };
        media-visualizer = {
          type = "audio_visualizer";
          # v4's default "linear" spectrum was bottom-aligned and mirrored.
          mirrored = true;
          centered = false;
          show_when_idle = false;
        };
        clock = {
          format = "{:%-I:%M %p | %a • %b | %Y-%m-%d}";
          vertical_format = "{:%I\n%M\n%p • %m\n%d}";
          tooltip_format = "{:%-I:%M %p %a, %b %d}";
          capsule_padding = 8;
          color = "secondary";
        };
        cpu = {
          type = "sysmon";
          stat = "cpu_usage";
          icon_color = "tertiary";
        };
        cpu-temp = {
          type = "sysmon";
          stat = "cpu_temp";
          icon_color = "tertiary";
        };
        memory = {
          type = "sysmon";
          stat = "ram_pct";
          icon_color = "tertiary";
        };
        disk = {
          type = "sysmon";
          stat = "disk_used_pct";
          path = "/";
          icon_color = "tertiary";
        };
        output-volume = {
          type = "volume";
          device = "output";
          show_label = true;
          icon_color = "tertiary";
          actions.middle = "exec ${lib.getExe pkgs.pwvucontrol}";
        };
        input-volume = {
          type = "volume";
          device = "input";
          show_label = true;
          icon_color = "tertiary";
          actions.middle = "exec ${lib.getExe pkgs.pwvucontrol}";
        };
        brightness = {
          show_label = true;
          icon_color = "tertiary";
        };
        battery = {
          display_mode = "glyph";
          show_label = true;
        };
        bluetooth = {
          show_label = false;
          icon_color = "tertiary";
        };
        network = {
          show_label = false;
          icon_color = "tertiary";
        };
      };

      dock.enabled = false;
      desktop_widgets.enabled = false;

      # v4's Rope plugin is replaced by the native screenshot-region command.
      # The old Custom Commands plugin had no user-defined entries to migrate.
      plugins = {
        enabled = [
          "alexander/screen-toolkit"
          "fel/ocr"
          "h-jangra/region-recorder"
          "noctalia/bitwarden"
          "noctalia/wallhaven"
          "oldirtty/color_picker"
          "vn1k/cursor"
        ];
        auto_update = "all";
      };

      # gpu-screen-recorder does not recognize Mesa's NVK driver. Region
      # Recorder can instead use wf-recorder's tested software H.264 path while
      # Noctalia still owns region selection, lifecycle, and notifications.
      plugin_settings."h-jangra/region-recorder" = {
        video_source = "region";
        directory = "~/Videos";
        filename_pattern = "%Y-%m-%d_%H-%M-%S";
        audio_source = "both";
        copy_to_clipboard = true;
      };
    };
  };
}
