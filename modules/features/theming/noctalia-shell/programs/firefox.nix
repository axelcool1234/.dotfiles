{ pkgs, ... }:
let
  # This file exists only to trigger Pywalfox after Noctalia updates Firefox's
  # generated theme data. Noctalia itself still owns the real Firefox template
  # output; we just need a stable post-hook entry point.
  pywalfoxTriggerTemplate = pkgs.writeText "pywalfox-trigger.css" ''
    /* No-op template used only to trigger pywalfox update via Noctalia post_hook. */
  '';
in
{
  # Extra Noctalia user-template entries to merge into user-templates.toml.
  userTemplates = {
    templates.pywalfox = {
      input_path = pywalfoxTriggerTemplate;
      output_path = "~/.cache/noctalia/pywalfox-trigger.css";
      post_hook = "${pkgs.pywalfox-native}/bin/pywalfox update";
    };
  };
}
