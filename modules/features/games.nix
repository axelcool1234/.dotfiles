{ selfPkgs, ... }:
{
  environment.systemPackages = [
    selfPkgs.mqreborn
  ];
}
