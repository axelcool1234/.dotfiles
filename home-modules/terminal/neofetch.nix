{ pkgs, lib, config, ... }: {  
  options = {
    neofetch.enable = 
      lib.mkEnableOption "enables neofetch config";
  };
  config = lib.mkIf config.neofetch.enable {
    xdg.configFile.neofetch.source = ./neofetch;
  };
}
