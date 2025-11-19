{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  program = "nushell";
  program-module = config.modules.${program};
  # nix-index-pkg = inputs.nix-index-database.packages.${pkgs.system}.nix-index-with-db;
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program}.enable = true;
    xdg.configFile.${program} = {
      source = ./.;
      recursive = true;
    };

    # NOTE: Despite what is said below, command-not-found.nu is quite slow and I'm not sure why. Instead,
    # I have opted to use the default command-not-found which is enabled in my nix-tools directory.
    # TODO: Figure out why it's slow, and determine what is the best way to go about all of this...
    # Once nix-index-database updates to a newer nix-index version, the following PR will be applied:
    # https://github.com/nix-community/nix-index/pull/276
    # Once that's the case, the following configuration should be used instead of above.
    # command-not-found.nu has copied for now.

    # programs.${program} = {
    #   enable = true;
    #   configFile.source = ./config.nu;
    #   extraConfig = # nu
    #     ''
    #       $env.config.hooks.command_not_found = source ${nix-index-pkg}/etc/profile.d/command-not-found.nu
    #     '';
    # };
    # home.file = {
    #   ".config/nushell/catppuccin_mocha.nu".source = ./catppuccin_mocha.nu;
    #   ".config/nushell/catppuccin_macchiato.nu".source = ./catppuccin_macchiato.nu;
    #   ".config/nushell/hhx.nu".source = ./hhx.nu;
    # };
  };
}
