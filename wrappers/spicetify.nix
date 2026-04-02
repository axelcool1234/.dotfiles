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

  config = {
    package =
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
          ];
        };
  };
}
