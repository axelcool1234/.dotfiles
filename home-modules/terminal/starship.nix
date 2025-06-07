{ pkgs, lib, config, ... }: {  
  options = {
    starship.enable = 
      lib.mkEnableOption "enables starship config";
  };
  config = lib.mkIf config.starship.enable {
    xdg.configFile.starship.source = ./starship;
  };
}
