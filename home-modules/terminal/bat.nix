{ pkgs, lib, config, ... }: {  
  options = {
    bat.enable = 
      lib.mkEnableOption "enables bat config";
  };
  config = lib.mkIf config.bat.enable {
    xdg.configFile.bat.source = ./bat;
  };
}
