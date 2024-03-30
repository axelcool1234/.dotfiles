{ pkgs, lib, config, ... }: {
  options = {
    firefox.enable =
      lib.mkEnableOption "enables firefox config";
  };
  config = lib.mkIf config.firefox.enable {
    programs.firefox = {
      enable = true;
      policies = {
        ExtensionSettings = with builtins;
        let extension = shortId: uuid: {
            name = uuid;
            value = {
                install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
                installation_mode = "normal_installed";
            };
        };
        in listToAttrs [
            (extension "ublock-origin" "uBlock0@raymondhill.net")
            (extension "tridactyl-vim" "tridactyl.vim@cmcaine.co.uk")
            (extension "tokyo-night-v3" "{6c8ef7a0-0691-4323-8bdc-af24f54985ec}")
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
  };
}
