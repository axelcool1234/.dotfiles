{ pkgs, lib, config, ... }: {  
  options = {
    tealdeer.enable = 
      lib.mkEnableOption "enables tealdeer config";
  };
  config = lib.mkIf config.tealdeer.enable {
    xdg.configFile.tealdeer.source = ./tealdeer;
  };
}
