{ inputs, pkgs, lib, config, ... }: {  
  options = {
    wezterm.enable = 
      lib.mkEnableOption "enables wezterm lua config";
  };
  config = lib.mkIf config.wezterm.enable {
    xdg.configFile.wezterm.source = ./wezterm;
    programs.wezterm = {
        enable = true;
        package = inputs.wezterm.packages.${pkgs.system}.default;
    };
  };
}
