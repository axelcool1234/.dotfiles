{ pkgs, ... }:

{
  programs.fish.enable = true; # WARNING: Not sure if I need this enabled at the system level. I was given a warning when I tried to remove this. Keeping for now.
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.axelcool1234 = {
    isNormalUser = true;
    description = "Axel Sorenson";
    extraGroups = [ "networkmanager" "input" "wheel" "video" "audio" "tss" ];
    shell = pkgs.fish;
    packages = with pkgs; [];
  };
}
