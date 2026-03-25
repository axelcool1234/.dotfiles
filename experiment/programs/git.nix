{
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.git ];

  config = {
    settings = {
      user = {
        name = "Axel Sorenson";
        email = "AxelPSorenson@gmail.com";
      };
      init.defaultBranch = "main";
    };
  };
}
