{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:
let
  flake = builtins.getFlake (toString ./.);
  system = pkgs.stdenv.hostPlatform.system;

  self = rec {
    packages = import ./packages.nix {
      inherit self;
      inputs = flake.inputs;
    };
  };

  selfPkgs = self.packages.${system};

  watchedPackageNames = [
    "fish"
    "git"
    "glide-browser"
    "helix"
    "yazi"
  ];

  watchedPackages = map (name: selfPkgs.${name}) watchedPackageNames;
in
pkgs.mkShell {
  packages = [
    pkgs.direnv
    pkgs.fd
    pkgs.fzf
    pkgs.lorri
    pkgs.ripgrep
    pkgs.zoxide
  ] ++ watchedPackages;

  shellHook = ''
    export FLAKE_PATH="$PWD"
  '';
}
