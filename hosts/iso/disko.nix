{ selfPkgs, ... }:
{
  environment.systemPackages = [ selfPkgs.disko-install ];
}
