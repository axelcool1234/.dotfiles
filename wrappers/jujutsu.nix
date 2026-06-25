{
  pkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.jujutsu ];

  config = {
    extraPackages = [ pkgs.watchman ];

    settings = {
      user = {
        name = "Axel Sorenson";
        email = "AxelPSorenson@gmail.com";
      };

      fsmonitor.backend = "watchman";
      fsmonitor.watchman.register-snapshot-trigger = true;

      colors = {
        "diff token".underline = false;
        "diff added token".underline = false;
        "diff removed token".underline = false;
      };
    };
  };
}
