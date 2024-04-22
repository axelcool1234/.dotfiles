{ pkgs, lib, config, ... }: {  
  options = {
    lazygit.enable = 
      lib.mkEnableOption "enables lazygit config";
  };
  config = lib.mkIf config.lazygit.enable {
    xdg.configFile.lazygit.source = ./lazygit;
  };
}
