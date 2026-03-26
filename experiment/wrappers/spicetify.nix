{
  inputs,
  pkgs,
  wlib,
  system,
  ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${system};
  onekoExtension = {
    src = pkgs.fetchFromGitHub {
      owner = "kyrie25";
      repo = "spicetify-oneko";
      rev = "589a8cc3a3939b8c9fc4f2bd087ed433e9af5002";
      hash = "sha256-lestrf4sSwGbBqy+0J7u5IoU6xNKHh35IKZxt/phpNY=";
    };
    name = "oneko.js";
  };
in
{
  imports = [ wlib.modules.default ];

  config.package = inputs.spicetify-nix.lib.mkSpicetify pkgs {
    enabledExtensions = with spicePkgs.extensions; [
      adblock
      shuffle
      keyboardShortcut
      fullAppDisplay
      onekoExtension
    ];
  };
}
