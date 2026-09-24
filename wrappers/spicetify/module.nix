{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options.spicetifyPackage = lib.mkPackageOption pkgs "Spicetify CLI" {
    default = "spicetify-cli";
  };

  config = {
    package = lib.mkDefault pkgs.spotify;

    # Ship the CLI beside the Spotify launcher so consumers can depend on one
    # wrapper package and still run Noctalia's Spicetify post-hook.
    wrapperVariants.spicetify = {
      mirror = false;
      package = config.spicetifyPackage;
      exePath = "bin/spicetify";
      binName = "spicetify";
    };

    passthru.spicetifyPackage = config.spicetifyPackage;

    meta = {
      description = "Spotify with a colocated Spicetify CLI";
      platforms = lib.platforms.linux;
    };
  };
}
