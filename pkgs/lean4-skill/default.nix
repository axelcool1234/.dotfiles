{ lib, pkgs, ... }:
let
  src = pkgs.fetchFromGitHub {
    owner = "cameronfreer";
    repo = "lean4-skills";
    rev = "12ea2a3058e7145efd49a84af13ff64bd53343cf";
    hash = "sha256-PpvaSo++OD4iXQ5gUbkTKnGs/S6wsry6iVnaZACt/o8=";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "lean4-skill";
  version = "unstable-2026-04-05";

  inherit src;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r plugins/lean4/skills/lean4/* "$out/"
    mkdir -p "$out/lib"
    cp -r plugins/lean4/lib/scripts "$out/lib/"
    runHook postInstall
  '';

  meta = {
    description = "Lean 4 Code skill bundle with helper scripts";
    homepage = "https://github.com/cameronfreer/lean4-skills";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
