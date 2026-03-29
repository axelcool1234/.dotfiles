{
  inputs,
  self,
  pkgs,
  wlib,
  system,
  ...
}:
let
  # Keep the old immutable Nix-built Spicetify package available for non-Noctalia
  # shells. The Noctalia path uses Flatpak Spotify instead.
  spicePkgs = inputs.spicetify-nix.legacyPackages.${system};

  # The entire Flatpak launcher path is only for the Noctalia desktop shell.
  # Other shells keep using the simpler prebuilt Spicetify package below.
  useNoctaliaTheme = self.defaults.desktop-shell == "noctalia-shell";

  # Still keep Oneko wired into the fallback Nix-built package path.
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
    runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.flatpak pkgs.procps ];
    text = ''
      # Launch the Flatpak Spotify app directly. We keep the debugger flags so
      # manual debugging/live-reload experiments stay available, but do not start
      # `watch -l` automatically because a forced `window.location.reload()` has
      # proven too destructive for the patched Spotify UI. However the manual
      # hook also calls `window.loacation.reload()`, so unsure what the problem
      # is with `watch -l`.
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
      # Under Noctalia, opening "Spotify" should really open the Flatpak app so
      # Spicetify can patch and refresh it imperatively.
      flatpakSpotifyLauncher
    else
      # Outside Noctalia, keep the old declarative fully-built Spicetify package.
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
