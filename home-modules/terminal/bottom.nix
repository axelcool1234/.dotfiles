{ pkgs, lib, config, ... }: {  
  options = {
    bottom.enable = 
      lib.mkEnableOption "enables bottom config";
  };
  config = lib.mkIf config.bottom.enable {
    xdg.configFile.bottom.source = ./bottom;
  };
}
