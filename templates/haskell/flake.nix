{
  description = "Haskell Env";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in
    {
      devShells = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          myHaskellEnv = pkgs.haskellPackages.ghcWithHoogle (
            haskellPackages:
            with haskellPackages;
            [
              haskell-language-server
              random
            ]
          );

          kics2 = pkgs.writeShellScriptBin "kics2" ''
            #!/bin/sh
            DOCKEROPTS="-it --rm"
            DOCKEROPTS="$DOCKEROPTS -v `pwd`:`pwd` -w `pwd` -v $HOME:$HOME -e HOME=$HOME"
            DOCKEROPTS="$DOCKEROPTS -u $(id -u):$(id -g)"

            DOCKERTAG="currylang/kics2"
            ENTRYPOINT=""
            HELP=no

            case $1 in
              --help | -h | -\? ) HELP=yes ;;
            esac

            if [ $HELP = yes ] ; then
              echo "Usage: kics2-docker.sh [-h|-?|--help] [-t TAG] [options]"
              echo ""
              echo "with options:"
              echo ""
              echo "-h|-?|--help       : show this message and quit"
              echo "-t TAG             : use docker image with tag TAG (default: $DOCKERTAG)"
              echo "cypm <opts>        : invoke Curry Package Manager with <opts>"
              echo "curry-check <opts> : invoke CurryCheck with <opts>"
              echo "curry-doc   <opts> : invoke CurryDoc with <opts>"
              echo "kics2 <opts>       : invoke KiCS2 with <opts>"
              echo "<opts>             : invoke KiCS2 with <opts>"
              exit
            fi

            if [ $# -gt 1 -a "$1" = "-t" ] ; then
              shift ; DOCKERTAG=$1 ; shift
            fi

            case $1 in
              kics2             ) shift ;;
              cypm              ) shift ; ENTRYPOINT="/kics2/kics2/bin/cypm" ;;
              curry-check       ) shift ; ENTRYPOINT="/kics2/cpm/bin/curry-check" ;;
              curry-doc         ) shift ; ENTRYPOINT="/kics2/cpm/bin/curry-doc" ;;
            esac

            if [ -n "$ENTRYPOINT" ] ; then
              DOCKEROPTS="$DOCKEROPTS --entrypoint=$ENTRYPOINT"
            fi

            docker run $DOCKEROPTS $DOCKERTAG ''${1+"$@"}
          '';
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              kics2
              myHaskellEnv
              pakcs
            ];
          };
        }
      );
    };
}
