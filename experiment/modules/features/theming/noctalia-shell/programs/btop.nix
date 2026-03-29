{ pkgs, ... }:
let
  # Noctalia already writes the live btop theme file into
  # ~/.config/btop/themes/noctalia.theme. This user template only exists to
  # trigger btop's hot-reload path after the theme file changes.
  btopReloadTrigger = pkgs.writeText "btop-reload-trigger.txt" ''
    Noctalia btop reload trigger.
  '';
in
{
  userTemplates = {
    templates.btop-reload = {
      input_path = btopReloadTrigger;
      output_path = "~/.cache/noctalia/btop-reload-trigger.txt";
      post_hook = "pkill -USR2 btop || true";
    };
  };
}
