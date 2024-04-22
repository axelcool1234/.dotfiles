{ pkgs, lib, config, ... }: {  
  options = {
    zathura.enable = 
      lib.mkEnableOption "enables zathura config";
  };
  config = lib.mkIf config.zathura.enable {
    xdg.configFile.zathura.source = ./zathura;
  };
}
