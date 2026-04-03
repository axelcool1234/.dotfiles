{
  config,
  hostVars,
  lib,
  pkgs,
  selfPkgs,
  wlib,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktop-shell == "noctalia-shell";
in
{
  imports = [ wlib.wrapperModules.niri ];

  config = {
    escapingFunction = wlib.escapeShellArgWithEnv;

    # wrapperModules.niri runs `niri validate -c <generated config>`
    # so we need this stub so it won't fail.
    constructFiles.noctaliaStub = lib.mkIf useNoctaliaTheme {
      relPath = "noctalia.kdl";
      content = "";
    };

    runShell = lib.optionals useNoctaliaTheme [
      ''
        runtime_base="${"$"}{XDG_RUNTIME_DIR:-${"$"}{XDG_CACHE_HOME:-${"$"}HOME/.cache}}"
        runtime_dir="$(mktemp -d "$runtime_base/niri-wrapper.XXXXXX")"
        export NIRI_RUNTIME_CONFIG="$runtime_dir/config.kdl"
        export NIRI_CONFIG="$NIRI_RUNTIME_CONFIG"
        cp ${config.constructFiles.generatedConfig.path} "$NIRI_RUNTIME_CONFIG"

        noctalia_config_dir="${"$"}HOME/.config/niri"
        noctalia_config="$noctalia_config_dir/noctalia.kdl"
        mkdir -p "$noctalia_config_dir"

        # Keep the runtime include wired to the mutable user file so later
        # Noctalia theme updates are visible without restarting niri.
        if [ ! -e "$noctalia_config" ]; then
          cp ${config.constructFiles.noctaliaStub.path} "$noctalia_config"
        fi

        # The placeholder is only here to give Noctalia a writable target until
        # it renders the real theme file.
        if [ ! -w "$noctalia_config" ]; then
          chmod u+w "$noctalia_config"
        fi

        ln -sfn "$noctalia_config" "$runtime_dir/noctalia.kdl"
      ''
    ];

    settings = {
      spawn-at-startup = lib.optionals (hostVars.desktop-shell != null) [
        (lib.getExe selfPkgs.${hostVars.desktop-shell})
      ];

      prefer-no-csd = _: {};

      input = {
        workspace-auto-back-and-forth = _: {};
        mouse.accel-profile = "flat";
      };

      binds = {
        # Menus
        "Mod+SHIFT+D".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call launcher toggle";
        "Mod+W".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call wallpaper toggle";
        "Mod+Escape".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call sessionMenu toggle";
        "Mod+Ctrl+L".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call lockScreen lock";
        "Mod+Shift+Slash".show-hotkey-overlay = _: {};

        # Escape Hatch
        "Mod+Shift+Escape".toggle-keyboard-shortcuts-inhibit = _: { allow-inhibiting = false; };

        # Main Programs
        "Mod+T".spawn = "${lib.getExe selfPkgs.${hostVars.terminal}}";
        "Mod+B".spawn = "${lib.getExe selfPkgs.${hostVars.browser}}";
        "Mod+S".spawn = "${lib.getExe selfPkgs.spicetify}";
        "Mod+D".spawn = "${lib.getExe selfPkgs.nixcord}";

        # Video/Audio Control
        "XF86AudioRaiseVolume".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call volume increase";
        "XF86AudioLowerVolume".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call volume decrease";
        "XF86AudioMute".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call volume muteOutput";
        "XF86AudioMicMute".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call volume muteInput";

        "XF86MonBrightnessUp".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call brightness increase";
        "XF86MonBrightnessDown".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call brightness decrease";

        "Mod+P".spawn-sh = "${lib.getExe pkgs.playerctl} play-pause";
        "Mod+BracketLeft".spawn-sh = "${lib.getExe pkgs.playerctl} previous";
        "Mod+BracketRight".spawn-sh = "${lib.getExe pkgs.playerctl} next";

        # Movement
        "Mod+H".focus-column-or-monitor-left = _: {};
        "Mod+J".focus-window-or-workspace-down = _: {};
        "Mod+K".focus-window-or-workspace-up = _: {};
        "Mod+L".focus-column-or-monitor-right = _: {};

        "Mod+Shift+H".move-column-left-or-to-monitor-left = _: {};
        "Mod+Shift+J".move-window-down-or-to-workspace-down = _: {};
        "Mod+Shift+K".move-window-up-or-to-workspace-up = _: {};
        "Mod+Shift+L".move-column-right-or-to-monitor-right = _: {};

        "Mod+Shift+Ctrl+J".move-workspace-down = _: {};
        "Mod+Shift+Ctrl+K".move-workspace-up = _: {};

        "Mod+1".focus-workspace = 1;
        "Mod+2".focus-workspace = 2;
        "Mod+3".focus-workspace = 3;
        "Mod+4".focus-workspace = 4;
        "Mod+5".focus-workspace = 5;
        "Mod+6".focus-workspace = 6;
        "Mod+7".focus-workspace = 7;
        "Mod+8".focus-workspace = 8;
        "Mod+9".focus-workspace = 9;
        "Mod+0".focus-workspace = "w10";

        "Mod+Shift+1".move-column-to-workspace = 1;
        "Mod+Shift+2".move-column-to-workspace = 2;
        "Mod+Shift+3".move-column-to-workspace = 3;
        "Mod+Shift+4".move-column-to-workspace = 4;
        "Mod+Shift+5".move-column-to-workspace = 5;
        "Mod+Shift+6".move-column-to-workspace = 6;
        "Mod+Shift+7".move-column-to-workspace = 7;
        "Mod+Shift+8".move-column-to-workspace = 8;
        "Mod+Shift+9".move-column-to-workspace = 9;
        "Mod+Shift+0".move-column-to-workspace = "w10";

        "Mod+Minus".set-column-width = "-10%";
        "Mod+Equal".set-column-width = "+10%";
        "Mod+Shift+Minus".set-window-height = "-10%";
        "Mod+Shift+Equal".set-window-height = "+10%";

        "Mod+F".maximize-column = _: {};
        "Mod+SHIFT+Q".close-window = _: {};

        # Utils
        "Mod+R".spawn-sh = "${lib.getExe selfPkgs.region-recorder} toggle video";
        "Mod+Shift+R".spawn-sh = "${lib.getExe selfPkgs.region-recorder} toggle gif";
        "Mod+Shift+S".screenshot = _: { show-pointer = _: { }; };
      };
      workspaces = {
        w01 = _: { };
        w02 = _: { };
        w03 = _: { };
        w04 = _: { };
        w05 = _: { };
        w06 = _: { };
        w07 = _: { };
        w08 = _: { };
        w09 = _: { };
        w10 = _: { };
      };
      window-rule = {
        open-maximized = true;
      };
      # https://github.com/liixini/shaders
      # https://github.com/XansiVA/nirimation
      # https://github.com/jgarza9788/niri-animation-collection
      animations = {
        window-resize = {
          spring = _: {
            props = {
              damping-ratio = 0.45;
              stiffness = 750;
              epsilon = 0.0003;
            };
          };
        };
        # https://easings.co/
        # https://easings.net/
        horizontal-view-movement = {
          # curve = [ "cubic-bezier" 0.68 (-0.6) 0.32 1.6 ]; # easeInOutBack
          # duration-ms = 600;
          spring = _: {
            props = {
              damping-ratio = 1.0;
              stiffness = 800;
              epsilon = 0.0001;
            };
          };
        };
        workspace-switch = {
          # curve = [ "cubic-bezier" 0.68 (-0.6) 0.32 1.6 ]; # easeInOutBack
          # duration-ms = 600;
          spring = _: {
            props = {
              damping-ratio = 1.0;
              stiffness = 1000;
              epsilon = 0.0001;
            };
          };
        };
        window-open = {
          duration-ms = 1500;
          curve = "ease-out-cubic";
          custom-shader = "            float hash(vec2 p) {
                return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
            }

            float noise(vec2 p) {
                vec2 i = floor(p);
                vec2 f = fract(p);
                f = f * f * (3.0 - 2.0 * f);
                float a = hash(i);
                float b = hash(i + vec2(1.0, 0.0));
                float c = hash(i + vec2(0.0, 1.0));
                float d = hash(i + vec2(1.0, 1.0));
                return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
            }

            float fbm(vec2 p) {
                float v = 0.0;
                float amp = 0.5;
                for (int i = 0; i < 6; i++) {
                    v += amp * noise(p);
                    p *= 2.0;
                    amp *= 0.5;
                }
                return v;
            }

            float warpedFbm(vec2 p, float t) {
                vec2 q = vec2(fbm(p + vec2(0.0, 0.0)),
                              fbm(p + vec2(5.2, 1.3)));

                vec2 r = vec2(fbm(p + 6.0 * q + vec2(1.7, 9.2) + 0.25 * t),
                              fbm(p + 6.0 * q + vec2(8.3, 2.8) + 0.22 * t));

                vec2 s = vec2(fbm(p + 5.0 * r + vec2(3.1, 7.4) + 0.18 * t),
                              fbm(p + 5.0 * r + vec2(6.7, 0.9) + 0.2 * t));

                return fbm(p + 6.0 * s);
            }

            vec4 open_color(vec3 coords_geo, vec3 size_geo) {
                float p = niri_clamped_progress;
                vec2 uv = coords_geo.xy;
                float seed = niri_random_seed * 100.0;

                float t = p * 12.0 + seed;

                float fluid = warpedFbm(uv * 2.0 + seed, t);

                vec2 center = uv - 0.5;
                float dist = length(center * vec2(1.0, 0.7));

                float appear = (1.0 - dist * 1.2) + (1.0 - fluid) * 0.7;
                float reveal = smoothstep(appear + 0.5, appear - 0.5, (1.0 - p) * 1.8);

                float distort_strength = (1.0 - p) * (1.0 - p) * 0.35;
                vec2 wq = vec2(fbm(uv * 2.0 + vec2(0.0, t * 0.2)),
                               fbm(uv * 2.0 + vec2(5.2, t * 0.2)));
                vec2 wr = vec2(fbm(uv * 2.0 + 4.0 * wq + vec2(1.7, 9.2)),
                               fbm(uv * 2.0 + 4.0 * wq + vec2(8.3, 2.8)));
                vec2 warped_uv = uv + (wr - 0.5) * distort_strength;

                vec3 tex_coords = niri_geo_to_tex * vec3(warped_uv, 1.0);
                vec4 color = texture2D(niri_tex, tex_coords.st);

                return color * reveal;
            }";
        };
        window-close = {
          duration-ms = 1500;
          curve = "ease-out-cubic";
          custom-shader = "
            float hash(vec2 p) {
                return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
            }

            float noise(vec2 p) {
                vec2 i = floor(p);
                vec2 f = fract(p);
                f = f * f * (3.0 - 2.0 * f);
                float a = hash(i);
                float b = hash(i + vec2(1.0, 0.0));
                float c = hash(i + vec2(0.0, 1.0));
                float d = hash(i + vec2(1.0, 1.0));
                return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
            }

            float fbm(vec2 p) {
                float v = 0.0;
                float amp = 0.5;
                for (int i = 0; i < 6; i++) {
                    v += amp * noise(p);
                    p *= 2.0;
                    amp *= 0.5;
                }
                return v;
            }

            float warpedFbm(vec2 p, float t) {
                vec2 q = vec2(fbm(p + vec2(0.0, 0.0)),
                              fbm(p + vec2(5.2, 1.3)));

                vec2 r = vec2(fbm(p + 6.0 * q + vec2(1.7, 9.2) + 0.25 * t),
                              fbm(p + 6.0 * q + vec2(8.3, 2.8) + 0.22 * t));

                vec2 s = vec2(fbm(p + 5.0 * r + vec2(3.1, 7.4) + 0.18 * t),
                              fbm(p + 5.0 * r + vec2(6.7, 0.9) + 0.2 * t));

                return fbm(p + 6.0 * s);
            }

            vec4 close_color(vec3 coords_geo, vec3 size_geo) {
                float p = niri_clamped_progress;
                vec2 uv = coords_geo.xy;
                float seed = niri_random_seed * 100.0;

                float t = p * 12.0 + seed;

                float fluid = warpedFbm(uv * 2.0 + seed, t);

                vec2 center = uv - 0.5;
                float dist = length(center * vec2(1.0, 0.7));

                float dissolve = (1.0 - dist) * 1.2 + fluid * 0.7;
                float remain = smoothstep(dissolve + 0.5, dissolve - 0.5, p * 1.8);

                float distort_strength = p * p * 0.4;
                vec2 wq = vec2(fbm(uv * 2.0 + vec2(0.0, t * 0.2)),
                               fbm(uv * 2.0 + vec2(5.2, t * 0.2)));
                vec2 wr = vec2(fbm(uv * 2.0 + 4.0 * wq + vec2(1.7, 9.2)),
                               fbm(uv * 2.0 + 4.0 * wq + vec2(8.3, 2.8)));
                vec2 warped_uv = uv + (wr - 0.5) * distort_strength;

                vec3 tex_coords = niri_geo_to_tex * vec3(warped_uv, 1.0);
                vec4 color = texture2D(niri_tex, tex_coords.st);

                float tail = smoothstep(1.0, 0.8, p);
                return color * remain * tail;
            }";
        };
      };

      outputs =
        if hostVars.hostName == "fermi" then
          {
            "DP-3" = {
              scale = 1.3333333;
              position = _: {
                props = {
                  x = -1920;
                  y = 0;
                };
              };
            };
            "DP-4" = {
              scale = 2.0;
              position = _: {
                props = {
                  x = 0;
                  y = 0;
                };
              };
            };
            "DP-1" = {
              scale = 0.625;
              transform = "90";
              position = _: {
                props = {
                  x = 1920;
                  y = -996;
                };
              };
            };
          }
        else
          { };

      xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

      extraConfig = lib.optionalString useNoctaliaTheme ''
        include "noctalia.kdl"
      '';
    };
  };
}
