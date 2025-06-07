{ pkgs, lib, config, ... }: {
  options = {
    nushell.enable =
      lib.mkEnableOption "enables nushell config";
  };
  config = lib.mkIf config.nushell.enable {
    xdg.configFile.nushell = {
        source = ./nushell;
        recursive = true;
    };
  };
}
