{
  lib,
  pkgs,
  ...
}:
let
  manifest = builtins.fromTOML (builtins.readFile ./manifest.toml);
  gleamToml = builtins.fromTOML (builtins.readFile ./gleam.toml);

  hexPackages = map (
    pkg: {
      checksum = pkg.outer_checksum;
      tarball = pkgs.fetchurl {
        url = "https://repo.hex.pm/tarballs/${pkg.name}-${pkg.version}.tar";
        hash = builtins.convertHash {
          hashAlgo = "sha256";
          hash = pkg.outer_checksum;
          toHashFormat = "sri";
        };
      };
    }
  ) (builtins.filter (pkg: pkg.source == "hex") manifest.packages);

  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: type:
      let
        base = builtins.baseNameOf path;
      in
      base != "build" && base != "result" && base != "flake.nix" && base != "flake.lock";
  };
in
pkgs.stdenv.mkDerivation rec {
  pname = "gleetcode";
  version = gleamToml.version;

  inherit src;

  nativeBuildInputs = [
    pkgs.gleam
    pkgs.beamPackages.erlang
    pkgs.beamPackages.rebar3
    pkgs.makeWrapper
  ];

  dontConfigure = true;
  doInstallCheck = true;

  buildPhase = ''
    runHook preBuild

    export HOME="$PWD/home"
    export XDG_CACHE_HOME="$HOME/.cache"
    mkdir -p "$XDG_CACHE_HOME/gleam/hex/hexpm/packages"

    ${lib.concatMapStringsSep "\n" (
      pkg: ''cp ${pkg.tarball} "$XDG_CACHE_HOME/gleam/hex/hexpm/packages/${pkg.checksum}.tar"''
    ) hexPackages}

    gleam export erlang-shipment

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/gleetcode" "$out/bin"
    cp -r build/erlang-shipment/. "$out/lib/gleetcode/"

    makeWrapper "$out/lib/gleetcode/entrypoint.sh" "$out/bin/glc" \
      --add-flags "run" \
      --prefix PATH : "${lib.makeBinPath [ pkgs.beamPackages.erlang ]}"

    runHook postInstall
  '';

  installCheckPhase = ''
    runHook preInstallCheck

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    "$out/bin/glc" --version | grep -F "glc ${version}"

    runHook postInstallCheck
  '';

  meta = {
    description = gleamToml.description;
    license = lib.licenses.mit;
    mainProgram = "glc";
    platforms = lib.platforms.unix;
  };
}
