{
  config,
  hostVars,
  inputs,
  lib,
  pkgs,
  selfPkgs,
  wlib,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktopShell == "noctalia-shell";

  activeTemplateIds = [
    "gtk"
    "qt"
    "discord"
    "pywalfox"
    "kitty"
    "zathura"
    "yazi"
    "btop"
  ]
  ++ lib.optional (hostVars.music == "spicetify") "spicetify"
  ++ lib.optional (hostVars.compositor == "niri") "niri";

  activeTemplates = map (id: {
    inherit id;
    enabled = true;
  }) activeTemplateIds;
in
{
  imports = [ wlib.wrapperModules.noctalia-shell ];

  config = {

    package = pkgs.noctalia-shell;

    # The local rope-screenshot plugin shells out to these helpers at runtime,
    # so keep them on the wrapped Noctalia PATH rather than in a broader module.
    runtimePkgs = [
      pkgs.grim
      pkgs.imagemagick
      pkgs.wl-clipboard
    ];

    passthru.persist = {
      # cliphist stores its database here.
      # also persist downloaded color schemes
      homeDirectories = [
        ".cache/cliphist"
        ".config/noctalia-shell/colorschemes"
      ];
      # This prevents noctalia-shell from showing the
      # privacy policy popup on every reboot
      homeFiles = [
        ".cache/noctalia/shell-state.json"
      ];
    };

    # Compositors consume these optional capabilities from whichever desktop
    # shell package is selected. Arguments are kept separate from the package
    # executable so consumers can safely construct their native command form.
    passthru.desktopShell.actions = {
      launcherToggle = [ "ipc" "call" "launcher" "toggle" ];
      wallpaperToggle = [ "ipc" "call" "wallpaper" "toggle" ];
      sessionMenuToggle = [ "ipc" "call" "sessionMenu" "toggle" ];
      lock = [ "ipc" "call" "lockScreen" "lock" ];
      volumeIncrease = [ "ipc" "call" "volume" "increase" ];
      volumeDecrease = [ "ipc" "call" "volume" "decrease" ];
      volumeMuteOutput = [ "ipc" "call" "volume" "muteOutput" ];
      volumeMuteInput = [ "ipc" "call" "volume" "muteInput" ];
      brightnessIncrease = [ "ipc" "call" "brightness" "increase" ];
      brightnessDecrease = [ "ipc" "call" "brightness" "decrease" ];
      screenshotRegion = [ "ipc" "call" "plugin:rope-screenshot" "takeScreenshot" "region" ];
    };

    preInstalledPlugins = {
      custom-commands.src = "${inputs.noctalia-plugins.outPath}/custom-commands";
      rope-screenshot.src = "${./plugins/rope-screenshot}";
    };

    # Make noctalia-shell's configuration mutable for color scheme selection and experimentation.
    escapingFunction = wlib.escapeShellArgWithEnv;
    outOfStoreConfig = ''${"$"}HOME/.config/noctalia-shell'';

    # `outOfStoreConfig` intentionally only fills missing files at ordinary
    # startup. This explicit helper lets a NixOS activation re-apply the new
    # declarative defaults without deleting unrelated mutable Noctalia state.
    constructFiles.sync-noctalia-shell-config = {
      relPath = "bin/sync-noctalia-shell-config";
      builder = ''${pkgs.coreutils}/bin/cp "$1" "$2" && ${pkgs.coreutils}/bin/chmod +x "$2"'';
      content = ''
        #!${pkgs.bash}/bin/bash
        set -eu

        config_dir="$HOME/.config/noctalia-shell"
        ${pkgs.coreutils}/bin/mkdir -p "$config_dir"
        ${pkgs.coreutils}/bin/cp -rf ${config.configPlaceholder}/. "$config_dir/"
        ${pkgs.findutils}/bin/find "$config_dir" ! -perm -u+w -exec ${pkgs.coreutils}/bin/chmod u+w {} +
      '';
    };

    settings = {
      templates = lib.mkIf useNoctaliaTheme {
        enableUserTheming = true;
        activeTemplates = activeTemplates;
      };
      general = {
        showChangelogOnStartup = false;
        telemetryEnabled = false;

        # Lock Screen
        lockScreenAnimations = true;
        lockOnSuspend = true;
        showSessionButtonsOnLockScreen = true;
        showHibernateOnLockScreen = true;
        enableLockScreenMediaControls = true;
        clockStyle = "custom";
        clockFormat = "h:mm AP";
        passwordChars = true;
        lockScreenBlur = 0.5;
        lockScreenTint = 0.25;
        lockScreenCountdownDuration = 5000;
      };
      bar = {
        # Bar Look
        barType = "floating";
        density = "spacious";
        frameThickness = 24;

        # Bar Behavior
        mouseWheelAction = "workspace";
        reverseScroll = true;
        mouseWheelWrap = true;

        middleClickAction = "controlCenter";
        middleClickFollowMouse = true;

        rightClickAction = "settings";
        rightClickFollowMouse = true;

        # Bar Widgets
        widgetSpacing = 3;
        contentPadding = 0;
        widgets = {
          left = [
            {
              id = "Workspace";
              pillSize = 0.7;
            }
            {
              id = "Taskbar";
            }
            {
              id = "Tray";
              colorizeIcons = true;
              chevronColor = "secondary";
            }
            {
              id = "MediaMini";
              maxWidth = 200;
              scrollingMode = "hover";
              showVisualizer = true;
              textColor = "secondary";
            }
          ];
          center = [
            {
              id = "Clock";
              formatHorizontal = "h:mm AP | ddd • MMM | yyyy-MM-dd";
              formatVertical = "hh mm AP • MM dd";
              tooltipFormat = "hh:mm AP ddd, MMM dd";
              clockColor = "secondary";
            }
          ];
          right = [
            {
              id = "SystemMonitor";
              compactMode = false;
              iconColor = "tertiary";
              showCpuCores = false;
              showCpuFreq = false;
              showCpuTemp = true;
              showCpuUsage = true;
              showDiskAvailable = false;
              showDiskUsage = true;
              showDiskUsageAsPercent = true;
              showGpuTemp = false;
              showLoadAverage = false;
              showMemoryAsPercent = true;
              showMemoryUsage = true;
            }
            {
              id = "Volume";
              displayMode = "alwaysShow";
              iconColor = "tertiary";
              middleClickCommand = "${lib.getExe pkgs.pwvucontrol}";
            }
            {
              id = "Microphone";
              displayMode = "alwaysShow";
              iconColor = "tertiary";
              middleClickCommand = "${lib.getExe pkgs.pwvucontrol}";
            }
            {
              id = "Brightness";
              applyToAllMonitors = true;
              displayMode = "alwaysShow";
              iconColor = "tertiary";
            }
            {
              id = "Battery";
              displayMode = "icon-always";
              hideIfIdle = false;
              hideIfNotDetected = false;
              showNoctaliaPerformance = true;
              showPowerProfiles = true;
            }
            {
              id = "Bluetooth";
              iconColor = "tertiary";
            }
            {
              id = "Network";
              iconColor = "tertiary";
            }
            {
              id = "SessionMenu";
            }
          ];
        };
      };
      dock = {
        enabled = false;
      };
      appLauncher = {
        enableClipboardHistory = true;
        clipboardWatchTextCommand = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${lib.getExe pkgs.cliphist} store";
        clipboardWatchImageCommand = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${lib.getExe pkgs.cliphist} store";
        position = "center";
        terminalCommand = lib.getExe selfPkgs.${hostVars.terminal};
        viewMode = "grid";
        density = "comfortable";
      };
      sessionMenu = {
        countdownDuration = 5000;
        largeButtonsLayout = "grid";
      };
    };
  };
}
