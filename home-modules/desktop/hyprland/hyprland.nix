{ pkgs, lib, config, ... }: {
  options = {
    hyprland.enable =
      lib.mkEnableOption "enables hyprland config";
  };

  config = lib.mkIf config.hyprland.enable {
    home.file.".config/hypr/hyprpaper.conf".source = ./hyprpaper.conf;
    # Wayland Configuraton
    wayland.windowManager.hyprland = {
      enable = true;
      settings = {
        exec-once = "hyprpaper &";
        "$mod" = "SUPER";
        "$terminal" = "wezterm";
        # monitor="DP-1,2560x1600@165,0x0,1";
        monitor="eDP-1,highres,auto,1";
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

          # Move focus with mod + arrow keys
          "$mod, left, movefocus, l"
          "$mod, right, movefocus, r"
          "$mod, up, movefocus, u"
          "$mod, down, movefocus, d"

          # Move focus with mod + hjkl
          "$mod, H, movefocus, l"
          "$mod, L, movefocus, r"
          "$mod, K, movefocus, u"
          "$mod, J, movefocus, d"

          # Move window with mod + shift + hjkl
          "$mod SHIFT, H, movewindow, l"
          "$mod SHIFT, L, movewindow, r"
          "$mod SHIFT, K, movewindow, u"
          "$mod SHIFT, J, movewindow, d"
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
        # Macchiato Theme
        "$rosewater" = "0xfff4dbd6";
        "$flamingo"  = "0xfff0c6c6";
        "$pink"      = "0xfff5bde6";
        "$mauve"     = "0xffc6a0f6";
        "$red"       = "0xffed8796";
        "$maroon"    = "0xffee99a0";
        "$peach"     = "0xfff5a97f";
        "$green"     = "0xffa6da95";
        "$teal"      = "0xff8bd5ca";
        "$sky"       = "0xff91d7e3";
        "$sapphire"  = "0xff7dc4e4";
        "$blue"      = "0xff8aadf4";
        "$lavender"  = "0xffb7bdf8";

        "$text"      = "0xffcad3f5";
        "$subtext1"  = "0xffb8c0e0";
        "$subtext0"  = "0xffa5adcb";

        "$overlay2"  = "0xff939ab7";
        "$overlay1"  = "0xff8087a2";
        "$overlay0"  = "0xff6e738d";

        "$surface2"  = "0xff5b6078";
        "$surface1"  = "0xff494d64";
        "$surface0"  = "0xff363a4f";

        "$base"      = "0xff24273a";
        "$mantle"    = "0xff1e2030";
        "$crust"     = "0xff181926";
      };
    };
    # Wayland packages
    home.packages = with pkgs; [
      (waybar.overrideAttrs (oldAttrs: {
        mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
       })
      )
      wofi      
      hyprpaper
    ];
  };
}
