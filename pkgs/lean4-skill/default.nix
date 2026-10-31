{ lib, pkgs, ... }:
let
  src = pkgs.fetchFromGitHub {
    owner = "cameronfreer";
    repo = "lean4-skills";
    rev = "83582df9d9172456993929f32ac4dd9d99c6211c";
    hash = "sha256-IXsV/FJlYQAdtVkN+04+G8/dwyggQ4+lYdP9G3Zpj1U=";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "lean4-skill";
  version = "unstable-2026-10-20";

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
