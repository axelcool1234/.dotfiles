{
  description = "Typst Environment";

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
          typst-zathura = pkgs.writeShellScriptBin "typst-zathura" ''
            #!/usr/bin/env bash
            set -euo pipefail
            if [ $# -lt 1 ]; then
              echo "Usage: $0 <file.typ>"
              exit 1
            fi
            file="$1"
            shift
            typst-live "-T" "$file" "$@" 2> >(
              while IFS= read -r line; do
                echo "$line" >&2
                if [[ "$line" == writing\ to* ]]; then
                  pdf=$(echo "$line" | sed -E 's/^writing to (.+\.pdf)$/\1/')
                  echo "Opening $pdf"
                  sleep 0.5
                  zathura "$pdf" &
                  break
                fi
              done
              cat >&2 )
          '';
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              zathura
              tinymist
              typst
              typst-live
              typst-zathura
            ];
          };
        }
      );
    };
}
