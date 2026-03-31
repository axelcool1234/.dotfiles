{
  config,
  inputs,
  lib,
  pkgs,
  self,
  wlib,
  ...
}:
let
  useNoctaliaTheme = self.defaults.desktop-shell == "noctalia-shell";

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

    preInstalledPlugins = {
      custom-commands.src = "${inputs.noctalia-plugins.outPath}/custom-commands";
    };

    settings = {
      templates = lib.mkIf useNoctaliaTheme {
        enableUserTheming = true;
        activeTemplates = activeTemplates;
      };
      general = {
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
        widgets = {
          left = [
            {
              id = "Workspace";
              pillSize = 0.7;
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
              id = "Bluetooth";
              iconColor = "tertiary";
            }
            {
              id = "Network";
              iconColor = "tertiary";
            }
            # {
            #   id = "Launcher";
            #   useDistroLogo = true;
            #   enableColorization = true;
            #   colorizeSystemIcon = "primary";
            # }
            {
              id = "Battery";
              displayMode = "icon-always";
              hideIfIdle = false;
              hideIfNotDetected = false;
              showNoctaliaPerformance = true;
              showPowerProfiles = true;
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
    };
  };
}
