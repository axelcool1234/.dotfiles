{
  baseVars,
  hostVars,
  inputs,
  lib,
  pkgs,
  selfPkgs,
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
  firefox = import ./programs/firefox.nix { inherit pkgs; };
  helix = import ./programs/helix.nix { inherit pkgs; };
  neovim = import ./programs/neovim.nix { inherit pkgs; };
  pi = import ./programs/pi.nix { inherit pkgs; };
  pearDesktop = import ./programs/pear-desktop.nix { inherit selfPkgs; };
  spotify = import ./programs/spotify.nix {
    inherit baseVars inputs lib pkgs;
  };
  usePearDesktop = hostVars.music == "pear-desktop";
  useSpicetify = hostVars.music == "spicetify";

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
        firefox.userTemplates
        helix.userTemplates
        neovim.userTemplates
        pi.userTemplates
        (lib.optionalAttrs usePearDesktop pearDesktop.userTemplates)
        (lib.optionalAttrs useSpicetify spotify.userTemplates)
      ]
  );
in
{
  config = lib.mkIf (hostVars.desktopShell == "noctalia-shell") (
    lib.mkMerge [
      {
        hjem.users.${baseVars.username} = {
          enable = true;
          clobberFiles = true;

          # Program-specific static files are merged here so there is still one
          # Hjem user block to read in the outer module.
          xdg.config.files = (lib.mapAttrs (_path: source: { inherit source; }) discord.homeFiles) // {
            # User templates are written declaratively too so noctalia-shell
            # sees them on first launch with no manual TOML editing.
            "noctalia-shell/user-templates.toml".source = noctaliaUserTemplates;
          };
        };
      }

      (lib.mkIf useSpicetify {
        services.flatpak.enable = spotify.enableFlatpak;
        xdg.portal = spotify.portalConfig;
        environment.systemPackages = spotify.packages;
        preferences.impermanence.persist.homeDirectories = spotify.persistHomeDirectories;

        hjem.users.${baseVars.username}.xdg.config.files = lib.mapAttrs (_path: source: {
          inherit source;
        }) spotify.homeFiles;

        systemd.user.services.spotify-flatpak-bootstrap = spotify.userService;
      })
    ]
  );
}
