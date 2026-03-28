{ wlib, pkgs, ... }:
let
  pywalfoxTriggerTemplate = pkgs.writeText "pywalfox-trigger.css" ''
    /* No-op template used only to trigger pywalfox update via Noctalia post_hook. */
  '';
in
{
  imports = [ wlib.wrapperModules.noctalia-shell ];

  config = {
    package = pkgs.noctalia-shell;

    settings.templates = {
      enableUserTemplates = false;
      gtk = true;
      qt = true;
      discord = true;
      pywalfox = true;
    };

    user-templates = {
      config = { };
      templates.pywalfox = {
        input_path = pywalfoxTriggerTemplate;
        output_path = "~/.config/noctalia/pywalfox-trigger.css";
        post_hook = "${pkgs.pywalfox-native}/bin/pywalfox update";
      };
    };
  };
}
