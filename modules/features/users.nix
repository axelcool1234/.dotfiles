{ baseVars, ... }:
{
  users.users.${baseVars.username} = {
    isNormalUser = true;
    initialPassword = "password";
    extraGroups = [ "wheel" ];
  };
}
