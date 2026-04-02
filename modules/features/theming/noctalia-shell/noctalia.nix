{
  config,
  baseVars,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Split program-specific Noctalia integrations into small files so each one
  # can explain its own generated files and hooks without piling everything into
  # one long module.
  discord = import ./programs/discord.nix {
    inherit inputs lib pkgs;
  };
  btop = import ./programs/btop.nix { inherit pkgs; };
  code = import ./programs/code.nix { inherit pkgs; };
  firefox = import ./programs/firefox.nix { inherit pkgs; };
  helix = import ./programs/helix.nix { inherit pkgs; };
  neovim = import ./programs/neovim.nix { inherit pkgs; };
  spotify = import ./programs/spotify.nix {
    inherit baseVars inputs lib pkgs;
  };

  # Merge all extra Noctalia user templates into one TOML file.
  # This keeps program-specific files independent while still producing the one
  # file Noctalia expects at runtime.
  noctaliaUserTemplates = (pkgs.formats.toml { }).generate "noctalia-user-templates.toml" (
    lib.foldl' lib.recursiveUpdate
      {
        config = { };
      }
      [
        btop.userTemplates
        code.userTemplates
        firefox.userTemplates
        helix.userTemplates
        neovim.userTemplates
        spotify.userTemplates
      ]
  );
in
{
  config = lib.mkIf (config.preferences.desktop-shell == "noctalia-shell") {
    # Only the Spotify integration needs Flatpak right now, but keeping the
    # enablement here still centralizes the “Noctalia-specific imperative app
    # theming” layer in one place.
    services.flatpak.enable = spotify.enableFlatpak;

    # Likewise, the portal requirement comes from the Flatpak Spotify path.
    xdg.portal = spotify.portalConfig;

    # Collect program-specific helper packages into the user environment.
    environment.systemPackages = spotify.packages;

    # The Noctalia Spotify path is the only place we intentionally use the
    # Flatpak app plus its user container, so keep that persistence policy here
    # with the rest of the integration instead of encoding it as a generic
    # wrapper-level special case.
    preferences.impermanence.persist.homeDirectories = spotify.persistHomeDirectories;

    hjem.users.${baseVars.username} = {
      enable = true;
      clobberFiles = true;

      # Program-specific static files are merged here so there is still one Hjem
      # user block to read in the outer module.
      xdg.config.files =
        (lib.mapAttrs (_path: source: { inherit source; }) discord.homeFiles)
        //
        (lib.mapAttrs (_path: source: { inherit source; }) spotify.homeFiles)
        // {
          # User templates are written declaratively too so Noctalia sees them on
          # first launch with no manual TOML editing.
          "noctalia/user-templates.toml".source = noctaliaUserTemplates;
        };
    };

    # Spotify still needs a one-time Flatpak + Spicetify bootstrap service.
    systemd.user.services.spotify-flatpak-bootstrap = spotify.userService;
  };
}
