{
  inputs,
  lib,
  config,
  ...
}:
with lib;
let
  program = "glide-browser";
  program-module = config.modules.${program};
in
{
  imports = [
    inputs.glide.homeModules.default
  ];

  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      policies = {
        ExtensionSettings =
          with builtins;
          let
            extension = shortId: uuid: {
              name = uuid;
              value = {
                install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
                installation_mode = "normal_installed";
              };
            };
          in
          listToAttrs [
            (extension "ublock-origin" "uBlock0@raymondhill.net")
            (extension "adaptive-tab-bar-colour" "ATBC@EasonWong")
            (extension "view-page-archive" "{d07ccf11-c0cd-4938-a265-2a4d6ad01189}")
          ];
        # To add additional extensions, find it on addons.mozilla.org, find
        # the short ID in the url (like https://addons.mozilla.org/en-US/firefox/addon/!SHORT_ID!/)
        # Then, download the XPI by filling it in to the install_url template, unzip it,
        # run `jq .browser_specific_settings.gecko.id manifest.json` or
        # `jq .applications.gecko.id manifest.json` to get the UUID
        #
        # You don’t need to get the UUID from the xpi.
        # You can install it then find the UUID in about:debugging#/runtime/this-firefox.
      };
    };

    xdg.configFile."glide/glide.ts".source = ./glide.ts;
  };
}
