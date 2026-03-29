{ pkgs, ... }:
let
  # Noctalia already writes the live Helix theme file into
  # ~/.config/helix/themes/noctalia.toml. This user template is only a trigger
  # so theme changes ask running Helix instances to reload their config.
  helixReloadTrigger = pkgs.writeText "helix-reload-trigger.txt" ''
    Noctalia Helix reload trigger.
  '';
in
{
  userTemplates = {
    templates.helix-reload = {
      input_path = helixReloadTrigger;
      output_path = "~/.cache/noctalia/helix-reload-trigger.txt";
      post_hook = "pkill -USR1 hx || true";
    };
  };
}
