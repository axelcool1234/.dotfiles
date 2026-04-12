{
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.jujutsu ];

  config = {
    settings = {
      user = {
        name = "Axel Sorenson";
        email = "AxelPSorenson@gmail.com";
      };
    };
  };
}
