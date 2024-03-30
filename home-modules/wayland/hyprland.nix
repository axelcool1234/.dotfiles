{ pkgs, lib, config, ... }: {
  options = {
    hyprland.enable =
      lib.mkEnableOption "enables hyprland config";
  };

  config = lib.mkIf config.hyprland.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      settings = {
        "$mod" = "SUPER";
        "$terminal" = "wezterm";
        # monitor="DP-1,2560x1600@165,0x0,1";
        monitor=",highres,auto,1";
        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
        };
        bind =
        [
          "$mod, F, exec, firefox"
          "$mod, D, exec, discord"
          "$mod, S, exec, spotify"
          "$mod, Q, exec, $terminal"
          "$mod, C, killactive"
          "$mod, M, exit"
          "$mod, V, togglefloating"
          "$mod, P, pseudo" # dwindle
          "$mod, J, togglesplit" # dwindle
        ]
        ++ (
          # workspaces
          # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
          builtins.concatLists (builtins.genList (
              x: let
                ws = let
                  c = (x + 1) / 10;
                in
                  builtins.toString (x + 1 - (c * 10));
              in [
                "$mod, ${ws}, workspace, ${toString (x + 1)}"
                "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
              ]
            )
            10)
        );
      };
    };
  };
}
