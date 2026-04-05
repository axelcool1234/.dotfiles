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
  useNoctaliaTheme = hostVars.desktop-shell == "noctalia-shell";

  activeTemplateIds = [
    "gtk"
    "qt"
    "discord"
    "pywalfox"
    "spicetify"
    "kitty"
    "zathura"
    "yazi"
    "helix"
    "btop"
    "niri"
  ];

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
    extraPackages = [
      pkgs.grim
      pkgs.imagemagick
      pkgs.wl-clipboard
    ];

    passthru.persist = {
      # cliphist stores its database here.
      # also persist downloaded color schemes
      homeDirectories = [
        ".cache/cliphist"
        "~/.config/noctalia-shell/colorschemes/"
      ];
      # This prevents noctalia-shell from showing the
      # privacy policy popup on every reboot
      homeFiles = [
        ".cache/noctalia/shell-state.json"
      ];
    };

    preInstalledPlugins = {
      custom-commands.src = "${inputs.noctalia-plugins.outPath}/custom-commands";
      rope-screenshot.src = "${./plugins/rope-screenshot}";
    };

    # Make noctalia-shell's configuration mutable for color scheme selection and experimentation.
    escapingFunction = wlib.escapeShellArgWithEnv;
    outOfStoreConfig = ''${"$"}HOME/.config/noctalia-shell'';

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
        terminalCommand = "${lib.getExe selfPkgs.${hostVars.terminal}}";
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
