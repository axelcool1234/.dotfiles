{ hostVars, selfPkgs, pkgs, ... }:
{
  environment.systemPackages = [
    selfPkgs.${hostVars.terminal}  # Default terminal
    selfPkgs.${hostVars.browser}   # Default browser
    selfPkgs.spicetify # Music
    selfPkgs.nixcord   # Casual communication
    pkgs.slack         # Work communication
    pkgs.pcmanfm       # File manager
  ];
}
