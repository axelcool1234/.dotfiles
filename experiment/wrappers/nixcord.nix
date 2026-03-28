{
  inputs,
  pkgs,
  self,
  wlib,
  system,
  ...
}:
let
  evaluated = inputs.nixpkgs.lib.nixosSystem {
    inherit system;

    modules = [
      inputs.nixcord.nixosModules.nixcord
      {
        programs.nixcord = {
          enable = true;
          user = "user";
          vesktop.enable = true;
          config = {
            plugins.oneko.enable = true;

            # Noctalia writes the Midnight Discord theme to `noctalia.theme.css`
            # inside the client's `themes/` directory. If Noctalia is the active
            # desktop shell, pre-enable that theme in Vesktop/Vencord.
            enabledThemes = inputs.nixpkgs.lib.optionals (self.defaults.desktop-shell == "noctalia-shell") [
              "noctalia.theme.css"
            ];
          };
        };
      }
    ];
  };
in
{
  imports = [ wlib.modules.default ];

  config.package = evaluated.config.programs.nixcord.finalPackage.vesktop;
}
