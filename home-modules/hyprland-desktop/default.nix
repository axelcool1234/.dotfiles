{
  pkgs,
  lib,
  config,
  hostname,
  themes,
  theme ? null,
  ...
}:
with lib;
let
  program = "hyprland"; # Technically not a program here
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable (
    let
      inherit (themes.helpers) getAppProvider resolveAssetSource resolveWrapperText;

      providerWrapperFile = provider:
        if provider == null then
          null
        else if provider ? wrapperFile && provider.wrapperFile != null then
          provider.wrapperFile
        else if provider.options ? wrapperFile && provider.options.wrapperFile != null then
          provider.options.wrapperFile
        else
          null;

      waybarProvider = getAppProvider theme "waybar";
      dunstProvider = getAppProvider theme "dunst";
      rofiProvider = getAppProvider theme "rofi";
      wlogoutProvider = getAppProvider theme "wlogout";
      gtkProvider = getAppProvider theme "gtk";
      kvantumProvider = getAppProvider theme "kvantum";
      cursorProvider = getAppProvider theme "cursor";

      gtkThemeName =
        if gtkProvider != null && gtkProvider.type == "module" && gtkProvider.options ? themeName then
          gtkProvider.options.themeName
        else
          throw "theme.apps.gtk.provider.options.themeName is required";

      gtkIconThemeName =
        if gtkProvider != null && gtkProvider.type == "module" && gtkProvider.options ? iconThemeName then
          gtkProvider.options.iconThemeName
        else
          throw "theme.apps.gtk.provider.options.iconThemeName is required";

      cursorGtkName =
        if cursorProvider != null && cursorProvider.type == "module" && cursorProvider.options ? gtkName then
          cursorProvider.options.gtkName
        else
          throw "theme.apps.cursor.provider.options.gtkName is required";

      cursorSize =
        if cursorProvider != null && cursorProvider.type == "module" && cursorProvider.options ? size then
          cursorProvider.options.size
        else
          throw "theme.apps.cursor.provider.options.size is required";

      kvantumThemeName =
        if kvantumProvider != null && kvantumProvider.options ? themeName then
          kvantumProvider.options.themeName
        else
          throw "theme.apps.kvantum.provider.options.themeName is required";

      waybarAssetSource = resolveAssetSource waybarProvider;
      dunstAssetSource = resolveAssetSource dunstProvider;
      kvantumAssetSource =
        if kvantumProvider != null && kvantumProvider.type == "asset" then
          resolveAssetSource kvantumProvider
        else
          null;
      rofiAssetSource = resolveAssetSource rofiProvider;
      wlogoutAssetSource =
        if wlogoutProvider != null && wlogoutProvider.type == "template" then
          null
        else
          resolveAssetSource wlogoutProvider;

      waybarColors =
        if waybarProvider != null
          && builtins.elem waybarProvider.type [ "asset+import" "template" ]
          && waybarProvider.options ? colors then
          waybarProvider.options.colors
        else
          throw "theme.apps.waybar.provider.options.colors is required";

      rofiWrapperDir =
        if rofiProvider != null && builtins.elem rofiProvider.type [ "asset+import" "template" ] then
          pkgs.runCommandLocal "rofi-config-dir" { } ''
            mkdir -p "$out"
            ln -s ${providerWrapperFile rofiProvider} "$out/config.rasi"
          ''
        else
          null;

      wlogoutWrapperDir =
        if wlogoutProvider != null && builtins.elem wlogoutProvider.type [ "asset+import" "template" ] then
          pkgs.runCommandLocal "wlogout-config-dir" { } ''
            mkdir -p "$out/icons"
            ln -s ${providerWrapperFile wlogoutProvider} "$out/style.css"
            ln -s ${./wlogout/layout} "$out/layout"
            ln -s ${./wlogout/icons/hibernate.png} "$out/icons/hibernate.png"
            ln -s ${./wlogout/icons/lock.png} "$out/icons/lock.png"
            ln -s ${./wlogout/icons/logout.png} "$out/icons/logout.png"
            ln -s ${./wlogout/icons/reboot.png} "$out/icons/reboot.png"
            ln -s ${./wlogout/icons/shutdown.png} "$out/icons/shutdown.png"
            ln -s ${./wlogout/icons/suspend.png} "$out/icons/suspend.png"
          ''
        else
          null;
    in
    mkMerge [
    {
      xdg.configFile.hypr.source = ./hyprland;
    # xdg.configFile.waybar.source = ./waybar;
    xdg.configFile."dunst/dunstrc".text = ''
      [global]
      font = "JetBrains Mono Regular 11"
      corner_radius = 10
      offset = 5x5
      origin = top-right
      notification_limit = 8
      gap_size = 7
      frame_width = 2
      width = 300
      height = 100
    '';
    xdg.configFile.mpv.source = ./mpv;
    xdg.configFile.rofi.source =
      if rofiWrapperDir != null then rofiWrapperDir else throw "theme.apps.rofi must use asset+import provider";
    xdg.configFile.wlogout.source =
      if wlogoutWrapperDir != null then wlogoutWrapperDir else throw "theme.apps.wlogout must use asset+import provider";
    xdg.configFile.avizo.source = ./avizo;
    xdg.configFile."xsettingsd/xsettingsd.conf".text = ''
      Net/ThemeName "${gtkThemeName}"
      Net/IconThemeName "${gtkIconThemeName}"
      Gtk/CursorThemeName "${cursorGtkName}"
      Gtk/CursorThemeSize ${toString cursorSize}
      Gtk/FontName "JetBrains Mono 11"
      Xft/Antialias 1
      Xft/Hinting 1
      Xft/HintStyle "hintslight"
    '';
    xdg.configFile.xfce4.source = ./xfce4;
    xdg.configFile.wpaperd.source = ./wpaperd;
    xdg.configFile.Thunar.source = ./Thunar;
    xdg.configFile."gtk-3.0/bookmarks".source = ./gtk-3.0/bookmarks;
    xdg.configFile."gtk-3.0/gtk.css".source = ./gtk-3.0/gtk.css;
    xdg.configFile."gtk-3.0/settings.ini".text = ''
      [Settings]
      gtk-theme-name=${gtkThemeName}
      gtk-icon-theme-name=${gtkIconThemeName}
      gtk-font-name=JetBrains Mono 11
      gtk-cursor-theme-name=${cursorGtkName}
      gtk-cursor-theme-size=${toString cursorSize}
    '';
    xdg.configFile."gtk-4.0/gtk.css".source = ./gtk-4.0/gtk.css;
    xdg.configFile."gtk-4.0/settings.ini".text = ''
      [Settings]
      gtk-theme-name=${gtkThemeName}
      gtk-icon-theme-name=${gtkIconThemeName}
      gtk-font-name=JetBrains Mono 11
      gtk-cursor-theme-name=${cursorGtkName}
      gtk-cursor-theme-size=${toString cursorSize}
    '';
    xdg.configFile.autostart.source = ./autostart;
    xdg.configFile.swappy.source = ./swappy;
    xdg.configFile.zellij.source = ./zellij;
    xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=${kvantumThemeName}
    '';
    home.file.".icons".source = ./.icons;
    home.file.".gtkrc-2.0".text = ''
      gtk-theme-name="${gtkThemeName}"
      gtk-icon-theme-name="${gtkIconThemeName}"
      gtk-cursor-theme-name="${cursorGtkName}"
      gtk-font-name="JetBrains Mono 11"
      gtk-menu-images=0
      gtk-cursor-theme-size=${toString cursorSize}
      gtk-button-images=0
      gtk-xft-antialias=1
      gtk-xft-hinting=1
      gtk-xft-hintstyle="hintslight"
      gtk-xft-rgba="none"
      gtk-xft-dpi=98304
    '';
    home.file.".face".source = ./.face;

    programs.waybar.enable = true;
    programs.waybar.style =
      if waybarProvider != null && waybarProvider.type == "asset+import" then
        resolveWrapperText waybarProvider
      else if waybarProvider != null && waybarProvider.type == "template" then
        builtins.readFile (providerWrapperFile waybarProvider)
      else
        throw "theme.apps.waybar must use asset+import provider";
    programs.waybar.settings =
      # Double Bar Config
      [
        # Top Bar Config
        {
          # Main Config
          name = "top_bar";
          layer = "top"; # Waybar at top layer
          position = "top"; # Waybar position (top|bottom|left|right)
          height = 36; # Waybar height (to be removed for auto height)
          spacing = 4; # Gaps between modules (4px)
          modules-left = [
            "hyprland/workspaces"
            "hyprland/submap"
          ];
          modules-center = [
            "clock#time"
            "custom/separator"
            "clock#week"
            "custom/separator_dot"
            "clock#month"
            "custom/separator"
            "clock#calendar"
          ];
          modules-right = [
            "bluetooth"
            "network"
            "group/misc"
            "custom/logout_menu"
          ];

          # Modules Config
          "hyprland/workspaces" = {
            on-click = "activate";
            format = "{icon}";
            format-icons = {
              "1" = "󰲠";
              "2" = "󰲢";
              "3" = "󰲤";
              "4" = "󰲦";
              "5" = "󰲨";
              "6" = "󰲪";
              "7" = "󰲬";
              "8" = "󰲮";
              "9" = "󰲰";
              "10" = "󰿬";

              # active = ""
              # default = ""
              # empty = ""
            };
            show-special = true;
            persistent-workspaces =
              # TODO: Doesn't work because it's pure so it can't see HOSTNAME!
              if hostname == "fermi" then
                {
                  DP-4 = [
                    1
                    2
                    3
                    4
                    5
                    6
                    7
                    8
                    9
                    10
                  ]; # ASUS (center)
                  DP-3 = [
                    11
                    12
                    13
                    14
                    15
                    16
                    17
                    18
                    19
                    20
                  ]; # Lenovo (left)
                  DP-1 = [ 21 ]; # HP (right)
                }
              else
                {
                  "*" = 10;
                };
          };

          "hyprland/submap" = {
            format = "<span color='${waybarColors.green}'>Mode:</span> {}";
            tooltip = false;
          };

          "clock#time" = {
            format = "{:%I:%M %p %Ez}";
            # locale = "en_US.UTF-8"
            # timezones = [ "America/Denver" ]
          };

          "custom/separator" = {
            format = "|";
            tooltip = false;
          };

          "custom/separator_dot" = {
            format = "•";
            tooltip = false;
          };

          "clock#week" = {
            format = "{:%a}";
          };

          "clock#month" = {
            format = "{:%h}";
          };

          "clock#calendar" = {
            format = "{:%F}";
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            actions = {
              on-click-right = "mode";
            };
            calendar = {
              mode = "month";
              mode-mon-col = 3;
              weeks-pos = "right";
              on-scroll = 1;
              on-click-right = "mode";
              format = {
                months = "<span color='${waybarColors.rosewater}'><b>{}</b></span>";
                days = "<span color='${waybarColors.text}'><b>{}</b></span>";
                weeks = "<span color='${waybarColors.mauve}'><b>W{}</b></span>";
                weekdays = "<span color='${waybarColors.green}'><b>{}</b></span>";
                today = "<span color='${waybarColors.teal}'><b><u>{}</u></b></span>";
              };
            };
          };

          clock = {
            format = "{:%I:%M %p %Ez | %a • %h | %F}";
            format-alt = "{:%I:%M %p}";
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            # locale = "en_US.UTF-8"
            # timezones = [ "America/Denver" ]
            actions = {
              on-click-right = "mode";
            };
            calendar = {
              mode = "month";
              mode-mon-col = 3;
              weeks-pos = "right";
              on-scroll = 1;
              on-click-right = "mode";
              format = {
                months = "<span color='${waybarColors.rosewater}'><b>{}</b></span>";
                days = "<span color='${waybarColors.text}'><b>{}</b></span>";
                weeks = "<span color='${waybarColors.mauve}'><b>W{}</b></span>";
                weekdays = "<span color='${waybarColors.green}'><b>{}</b></span>";
                today = "<span color='${waybarColors.teal}'><b><u>{}</u></b></span>";
              };
            };
          };

          "custom/media" = {
            format = "{icon}󰎈";
            restart-interval = 2;
            return-type = "json";
            format-icons = {
              Playing = "";
              Paused = "";
            };
            max-length = 35;
            exec = "fish -c fetch_music_player_data";
            on-click = "playerctl play-pause";
            on-click-right = "playerctl next";
            on-click-middle = "playerctl prev";
            on-scroll-up = "playerctl volume 0.05-";
            on-scroll-down = "playerctl volume 0.05+";
            smooth-scrolling-threshold = "0.1";
          };

          bluetooth = {
            format = "󰂯";
            format-disabled = "󰂲";
            format-connected = "󰂱 {device_alias}";
            format-connected-battery = "󰂱 {device_alias} (󰥉 {device_battery_percentage}%)";
            # format-device-preference = [ "device1" "device2" ] # preference list deciding the displayed device
            tooltip-format = "{controller_alias}\t{controller_address} ({status})\n\n{num_connections} connected";
            tooltip-format-disabled = "bluetooth off";
            tooltip-format-connected = "{controller_alias}\t{controller_address} ({status})\n\n{num_connections} connected\n\n{device_enumerate}";
            tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
            tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t({device_battery_percentage}%)";
            max-length = 35;
            on-click = "fish -c bluetooth_toggle";
            on-click-right = "overskride";
          };

          "network" = {
            format = "󰤭";
            format-wifi = "{icon}({signalStrength}%){essid}";
            format-icons = [
              "󰤯"
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
            format-disconnected = "󰤫 Disconnected";
            tooltip-format = "wifi <span color='${waybarColors.maroon}'>off</span>";
            tooltip-format-wifi = "SSID: {essid}({signalStrength}%) {frequency} MHz\nInterface: {ifname}\nIP: {ipaddr}\nGW: {gwaddr}\n\n<span color='${waybarColors.green}'>{bandwidthUpBits}</span>\t<span color='${waybarColors.maroon}'>{bandwidthDownBits}</span>\t<span color='${waybarColors.mauve}'>󰹹{bandwidthTotalBits}</span>";
            tooltip-format-disconnected = "<span color='${waybarColors.red}'>disconnected</span>";
            # format-ethernet = "󰈀 {ipaddr}/{cidr}";
            # format-linked = "󰈀 {ifname} (No IP)";
            # tooltip-format-ethernet = "Interface: {ifname}\nIP: {ipaddr}\nGW: {gwaddr}\nNetmask: {netmask}\nCIDR: {cidr}\n\n<span color='#a6da95'>{bandwidthUpBits}</span>\t<span color='#ee99a0'>{bandwidthDownBits}</span>\t<span color='#c6a0f6'>󰹹{bandwidthTotalBits}</span>";
            max-length = 35;
            on-click = "fish -c wifi_toggle";
            on-click-right = "kitty nmtui";
          };

          "group/misc" = {
            orientation = "horizontal";
            modules = [
              "custom/webcam"
              "privacy"
              "custom/recording"
              "custom/geo"
              "custom/media"
              "custom/dunst"
              "custom/night_mode"
              "custom/airplane_mode"
              "idle_inhibitor"
            ];
          };

          "custom/webcam" = {
            interval = 1;
            exec = "fish -c check_webcam";
            return-type = "json";
          };

          privacy = {
            icon-spacing = 1;
            icon-size = 12;
            transition-duration = 250;
            modules = [
              {
                type = "audio-in";
              }
              {
                type = "screenshare";
              }
            ];
          };

          "custom/recording" = {
            interval = 1;
            exec-if = "pgrep wl-screenrec";
            exec = "fish -c check_recording";
            return-type = "json";
          };

          "custom/geo" = {
            interval = 1;
            exec-if = "pgrep geoclue";
            exec = "fish -c check_geo_module";
            return-type = "json";
          };

          "custom/airplane_mode" = {
            return-type = "json";
            interval = 1;
            exec = "fish -c check_airplane_mode";
            on-click = "fish -c airplane_mode_toggle";
          };

          "custom/night_mode" = {
            return-type = "json";
            interval = 1;
            exec = "fish -c check_night_mode";
            on-click = "fish -c night_mode_toggle";
          };

          "custom/dunst" = {
            return-type = "json";
            exec = "fish -c dunst_pause";
            on-click = "dunstctl set-paused toggle";
            restart-interval = 1;
          };

          idle_inhibitor = {
            format = "{icon}";
            format-icons = {
              activated = "󰛐";
              deactivated = "󰛑";
            };
            tooltip-format-activated = "idle-inhibitor <span color='${waybarColors.green}'>on</span>";
            tooltip-format-deactivated = "idle-inhibitor <span color='${waybarColors.maroon}'>off</span>";
            start-activated = true;
          };

          "custom/logout_menu" = {
            return-type = "json";
            exec = "echo '{ \"text\":\"󰐥\", \"tooltip\": \"logout menu\" }'";
            interval = "once";
            on-click = "fish -c wlogout_uniqe";
          };

        }

        # Bottom Bar Config
        {
          # Main Config
          name = "bottom_bar";
          layer = "top"; # Waybar at top layer
          position = "bottom"; # Waybar position (top|bottom|left|right)
          height = 36; # Waybar height (to be removed for auto height)
          spacing = 4; # Gaps between modules (4px)
          modules-left = [ "user" ];
          modules-center = [ "hyprland/window" ];
          modules-right = [
            "keyboard-state"
            "hyprland/language"
          ];

          # Modules Config
          "hyprland/window" = {
            format = " {title}  ";
            max-length = 50;
          };

          "hyprland/language" = {
            format-en = "🇺🇸 ENG (US)";
            keyboard-name = "at-translated-set-2-keyboard";
            on-click = "hyprctl switchxkblayout at-translated-set-2-keyboard next";
          };

          keyboard-state = {
            capslock = true;
            # numlock = true
            format = "{name} {icon}";
            format-icons = {
              locked = "󰌾";
              unlocked = "󰍀";
            };
          };

          user = {
            format = " <span color='${waybarColors.teal}'>{user}</span> (up <span color='${waybarColors.pink}'>{work_d} d</span> <span color='${waybarColors.blue}'>{work_H} h</span> <span color='${waybarColors.yellow}'>{work_M} min</span> <span color='${waybarColors.green}'>↑</span>)";
            icon = true;
          };
        }

        # Left Bar Config
        {
          # Main Config
          name = "left_bar";
          layer = "top"; # Waybar at top layer
          position = "left"; # Waybar position (top|bottom|left|right)
          spacing = 4; # Gaps between modules (4px)
          width = 75;
          margin-top = 10;
          margin-bottom = 10;
          modules-left = [ "wlr/taskbar" ];
          modules-center = [
            "cpu"
            "memory"
            "disk"
            "temperature"
            "battery"
            "backlight"
            "pulseaudio"
            "systemd-failed-units"
          ];
          modules-right = [ "tray" ];

          # Modules Config
          "wlr/taskbar" = {
            format = "{icon}";
            icon-size = 20;
            icon-theme = "Numix-Circle";
            tooltip-format = "{title}";
            on-click = "activate";
            on-click-right = "close";
            on-click-middle = "fullscreen";
          };

          tray = {
            icon-size = 20;
            spacing = 2;
          };

          cpu = {
            format = "󰻠 {usage}%";
            states = {
              high = 90;
              upper-medium = 70;
              medium = 50;
              lower-medium = 30;
              low = 10;
            };
            on-click = "kitty btop";
            on-click-right = "kitty btm";
          };

          memory = {
            format = " {percentage}%";
            tooltip-format = "Main: ({used} GiB/{total} GiB)({percentage}%) available {avail} GiB\nSwap: ({swapUsed} GiB/{swapTotal} GiB)({swapPercentage}%) available {swapAvail} GiB";
            states = {
              high = 90;
              upper-medium = 70;
              medium = 50;
              lower-medium = 30;
              low = 10;
            };
            on-click = "kitty btop";
            on-click-right = "kitty btm";
          };

          disk = {
            format = "󰋊 {percentage_used}%";
            tooltip-format = "({used}/{total})({percentage_used}%) in '{path}' available {free}({percentage_free}%)";
            states = {
              high = 90;
              upper-medium = 70;
              medium = 50;
              lower-medium = 30;
              low = 10;
            };
            on-click = "kitty btop";
            on-click-right = "kitty btm";
          };

          temperature = {
            tooltip = false;
            thermal-zone = 8;
            critical-threshold = 80;
            format = "{icon} {temperatureC}󰔄";
            format-critical = "🔥{icon} {temperatureC}󰔄";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
          };

          battery = {
            states = {
              high = 90;
              upper-medium = 70;
              medium = 50;
              lower-medium = 30;
              low = 10;
            };
            format = "{icon} {capacity}%";
            format-charging = "󱐋{icon} {capacity}%";
            format-plugged = "󰚥{icon} {capacity}%";
            format-time = "{H} h {M} min";
            format-icons = [
              "󱃍"
              "󰁺"
              "󰁻"
              "󰁼"
              "󰁽"
              "󰁾"
              "󰁿"
              "󰂀"
              "󰂁"
              "󰂂"
              "󰁹"
            ];
            tooltip-format = "{timeTo}";
          };

          backlight = {
            format = "{icon} {percent}%";
            format-icons = [
              "󰌶"
              "󱩎"
              "󱩏"
              "󱩐"
              "󱩑"
              "󱩒"
              "󱩓"
              "󱩔"
              "󱩕"
              "󱩖"
              "󰛨"
            ];
            tooltip = false;
            states = {
              high = 90;
              upper-medium = 70;
              medium = 50;
              lower-medium = 30;
              low = 10;
            };
            reverse-scrolling = true;
            reverse-mouse-scrolling = true;
          };

          pulseaudio = {
            states = {
              high = 90;
              upper-medium = 70;
              medium = 50;
              lower-medium = 30;
              low = 10;
            };
            tooltip-format = "{desc}";
            format = "{icon} {volume}%\n{format_source}";
            format-bluetooth = "󰂱{icon} {volume}%\n{format_source}";
            format-bluetooth-muted = "󰂱󰝟 {volume}%\n{format_source}";
            format-muted = "󰝟{volume}%\n{format_source}";
            format-source = "󰍬 {volume}%";
            format-source-muted = "󰍭 {volume}%";
            format-icons = {
              headphone = "󰋋";
              hands-free = "";
              headset = "󰋎";
              phone = "󰄜";
              portable = "󰦧";
              car = "󰄋";
              speaker = "󰓃";
              hdmi = "󰡁";
              hifi = "󰋌";
              default = [
                "󰕿"
                "󰖀"
                "󰕾"
              ];
            };
            reverse-scrolling = true;
            reverse-mouse-scrolling = true;
            on-click = "pavucontrol";
          };

          systemd-failed-units = {
            format = "✗ {nr_failed}";
          };
        }
      ];
    }
    (lib.optionalAttrs (waybarAssetSource != null) {
      xdg.configFile."${waybarProvider.target}".source = waybarAssetSource;
    })
    (lib.optionalAttrs (dunstAssetSource != null) {
      xdg.configFile."${dunstProvider.target}".source = dunstAssetSource;
    })
    (lib.optionalAttrs (kvantumAssetSource != null) {
      xdg.configFile."${kvantumProvider.target}".source = kvantumAssetSource;
    })
    (lib.optionalAttrs (rofiAssetSource != null) {
      xdg.configFile."${rofiProvider.target}".source = rofiAssetSource;
    })
    (lib.optionalAttrs (wlogoutAssetSource != null) {
      xdg.configFile."${wlogoutProvider.target}".source = wlogoutAssetSource;
    })
  ]);
}
