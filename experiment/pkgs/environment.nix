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

  package = selfPkgs.fish;

  runtimeInputs = [
    selfPkgs.glide-browser
    selfPkgs.helix
    selfPkgs.git
    selfPkgs.spicetify
    selfPkgs.yazi

    pkgs.btop
    pkgs.lazygit
    pkgs.yazi
    pkgs.zoxide
    pkgs.ripgrep
    pkgs.fd
    pkgs.fzf
    pkgs.fastfetch
    pkgs.zathura
    pkgs.imv
    pkgs.mpv
    pkgs.scooter
    pkgs.slack

    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.code
  ];

  env = {
    EDITOR = "${selfPkgs.helix}/bin/hx";
  };
}
