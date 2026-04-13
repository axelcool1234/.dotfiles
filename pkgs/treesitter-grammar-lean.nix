{ pkgs, ... }:
let
  src = pkgs.fetchFromGitHub {
    owner = "Julian";
    repo = "tree-sitter-lean";
    rev = "4f5ec1592d040dd419891395a9f5503170e18155";
    hash = "sha256-MF+LRzhDw3V/l/h11ZTyWCUCm3b+g0oyOdaCZMVlJc4=";
  };

  builtGrammar = pkgs.tree-sitter.buildGrammar {
    language = "lean";
    version = "0.0.0+rev=4f5ec15";
    inherit src;
  };
in
pkgs.runCommand "treesitter-grammar-lean-${builtGrammar.version}"
  {
    inherit src;
    meta.homepage = "https://github.com/Julian/tree-sitter-lean";
  }
  ''
    mkdir -p "$out/parser"
    cp ${builtGrammar}/parser "$out/parser/lean.so"
  ''
