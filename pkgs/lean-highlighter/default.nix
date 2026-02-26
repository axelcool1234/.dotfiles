{
  pkgs ? import <nixpkgs> { },
}:

let
  tree-sitter-lean = pkgs.fetchFromGitHub {
    owner = "Julian";
    repo = "tree-sitter-lean";
    rev = "master";
    sha256 = "sha256-MF+LRzhDw3V/l/h11ZTyWCUCm3b+g0oyOdaCZMVlJc4=";
  };
in
pkgs.stdenv.mkDerivation {
  pname = "lean-highlighter";
  version = "0.1.0";

  src = ./.;

  buildInputs = [
    pkgs.tree-sitter
    pkgs.python3
    pkgs.jq
  ];

  installPhase = ''
    mkdir -p $out/share/tree-sitter
    mkdir -p $out/share/tree-sitter/tree-sitter-lean
    cp -r ${tree-sitter-lean}/* $out/share/tree-sitter/tree-sitter-lean/

    mkdir -p $out/share/tree-sitter/tree-sitter-lean/queries
    cp highlights.scm $out/share/tree-sitter/tree-sitter-lean/queries/highlights.scm

    jq '.grammars[0].highlights = "queries/highlights.scm"' "$out/share/tree-sitter/tree-sitter-lean/tree-sitter.json" > "$out/share/tree-sitter/tree-sitter-lean/tree-sitter.json.tmp"
    mv "$out/share/tree-sitter/tree-sitter-lean/tree-sitter.json.tmp" "$out/share/tree-sitter/tree-sitter-lean/tree-sitter.json"

    mkdir -p $out/bin
    cp highlighter.py $out/bin/highlighter.py

    ${pkgs.python3}/bin/python3 -u $out/bin/highlighter.py \
      --print-tree-sitter-config "$out/share/tree-sitter" > \
      $out/share/tree-sitter/config.json

    cat > $out/bin/lean-highlight <<EOF
    #!/usr/bin/env bash
    # tree-sitter compiles parser sources into ~/.cache/tree-sitter on first run.
    export PATH="${pkgs.stdenv.cc}/bin:${pkgs.tree-sitter}/bin:\$PATH"
    exec ${pkgs.python3}/bin/python3 -u $out/bin/highlighter.py "\$@"
    EOF

    cat > $out/bin/lean-semantic-highlight <<EOF
    #!/usr/bin/env bash
    if [ "\$#" -lt 1 ]; then
      echo "Usage: lean-semantic-highlight <file>"
      exit 1
    fi
    exec $out/bin/lean-highlight --semantic "\$1"
    EOF

    cat > $out/bin/lean-mixed-highlight <<EOF
    #!/usr/bin/env bash
    if [ "\$#" -lt 1 ]; then
      echo "Usage: lean-mixed-highlight <file>"
      exit 1
    fi
    exec $out/bin/lean-highlight --mixed "\$1"
    EOF

    cat > $out/bin/lean-treesitter-highlight <<EOF
    #!/usr/bin/env bash
    if [ "\$#" -lt 1 ]; then
      echo "Usage: lean-treesitter-highlight <file>"
      exit 1
    fi
    exec $out/bin/lean-highlight --treesitter "\$1"
    EOF

    cat > $out/bin/lean-pretty <<EOF
    #!/usr/bin/env bash
    if [ "\$#" -lt 1 ]; then
      echo "Usage: lean-pretty <file>"
      exit 1
    fi
    exec $out/bin/lean-highlight --pretty "\$@"
    EOF

    chmod +x $out/bin/lean-highlight
    chmod +x $out/bin/lean-semantic-highlight
    chmod +x $out/bin/lean-mixed-highlight
    chmod +x $out/bin/lean-treesitter-highlight
    chmod +x $out/bin/lean-pretty
  '';
}
