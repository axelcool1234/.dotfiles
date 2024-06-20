{ pkgs, lib, config, ... }: {  
  options = {
    nvim.enable = 
      lib.mkEnableOption "enables nvim config";
  };
  config = lib.mkIf config.nvim.enable {
    xdg.configFile.nvim.source = ./nvim;
  };
}
