{
  inputs,
  self,
  pkgs,
  wlib,
  system,
  ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${system};
  useNoctaliaTheme = self.defaults.desktop-shell == "noctalia-shell";
  onekoExtension = {
    src = pkgs.fetchFromGitHub {
      owner = "kyrie25";
      repo = "spicetify-oneko";
      rev = "589a8cc3a3939b8c9fc4f2bd087ed433e9af5002";
      hash = "sha256-lestrf4sSwGbBqy+0J7u5IoU6xNKHh35IKZxt/phpNY=";
    };
    name = "oneko.js";
  };

  flatpakSpotifyLauncher = pkgs.writeShellApplication {
    name = "spotify";
    runtimeInputs = [ pkgs.flatpak ];
    text = ''
      exec flatpak run --command=spotify com.spotify.Client \
        --remote-debugging-port=9222 \
        --remote-allow-origins=* \
        "$@"
    '';
  };
in
{
  imports = [ wlib.modules.default ];

  config.package =
    if useNoctaliaTheme then
      flatpakSpotifyLauncher
    else
      inputs.spicetify-nix.lib.mkSpicetify pkgs {
        enabledExtensions = with spicePkgs.extensions; [
          adblock
          shuffle
          keyboardShortcut
          fullAppDisplay
          onekoExtension
        ];
      };
}
