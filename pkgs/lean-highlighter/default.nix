{ pkgs, selfPkgs, ... }:
pkgs.stdenv.mkDerivation {
  pname = "lean-highlighter";
  version = "0.1.0";

  meta.mainProgram = "lean-highlight";

  src = ./.;

  buildInputs = [
    pkgs.tree-sitter
    pkgs.python3
    pkgs.jq
  ];

  installPhase = ''
    mkdir -p $out/share/tree-sitter
    mkdir -p $out/share/tree-sitter/tree-sitter-lean
    cp -r ${selfPkgs.treesitter-grammar-lean.src}/* $out/share/tree-sitter/tree-sitter-lean/

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

    chmod +x $out/bin/lean-highlight
  '';
}
