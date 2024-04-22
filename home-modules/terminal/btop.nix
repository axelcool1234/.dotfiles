{ pkgs, lib, config, ... }: {  
  options = {
    btop.enable = 
      lib.mkEnableOption "enables btop config";
  };
  config = lib.mkIf config.btop.enable {
    xdg.configFile.btop.source = ./btop;
  };
}
