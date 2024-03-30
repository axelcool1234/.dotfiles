{ pkgs, lib, config, ... }: {
  options = {
    git.enable =
      lib.mkEnableOption "enables git config";
  };
  config = lib.mkIf config.git.enable {
    programs.git = {
        enable = true;
        userName = "Axel Sorenson";
        userEmail = "AxelPSorenson@gmail.com";
    };
  };
}
