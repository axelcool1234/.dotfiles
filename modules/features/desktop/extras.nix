{ selfPkgs, pkgs, ... }:
{
  environment.systemPackages = [
    selfPkgs.terminal  # Default terminal
    selfPkgs.browser   # Default browser
    selfPkgs.spicetify # Music
    selfPkgs.nixcord   # Casual communication
    pkgs.slack         # Work communication
    pkgs.pcmanfm       # File manager
  ];
}
