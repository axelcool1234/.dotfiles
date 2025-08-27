{ pkgs, ... }:

{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.axelcool1234 = {
    isNormalUser = true;
    description = "Axel Sorenson";
    extraGroups = [
      "networkmanager"
      "input"
      "wheel"
      "video"
      "audio"
      "tss"
      "dialout"
      "docker"
    ];
    shell = pkgs.nushell;
    packages = with pkgs; [ ];
  };
}
