{
  self,
  inputs,
  pkgs,
  ...
}:
let
  selfPkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
in
inputs.wrappers.lib.wrapPackage {
  inherit pkgs;

  package = pkgs.fish;

  runtimeInputs = [
    # Editor (plus integrations)
    selfPkgs.helix
    selfPkgs.yazi

    selfPkgs.git

    pkgs.fd
    pkgs.fzf
    pkgs.jq
    pkgs.lazygit
    pkgs.ripgrep
    pkgs.zoxide
  ];

  env = {
    EDITOR = "${selfPkgs.helix}/bin/hx";
  };
}
