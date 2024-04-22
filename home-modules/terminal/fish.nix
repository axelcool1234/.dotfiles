{ pkgs, lib, config, ... }: 
{
  options = {
    fish.enable =
      lib.mkEnableOption "enables fish config";
  };
  config = lib.mkIf config.fish.enable {
    xdg.configFile.fish.source = ./fish;
  };
}
