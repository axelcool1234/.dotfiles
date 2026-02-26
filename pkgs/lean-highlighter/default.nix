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
  tree-sitter-config = parseDir: ''
    {
      "parser-directories": [
        "${parseDir}"
      ],
      "theme": {
        "attribute": {
          "color": 30
        },
        "comment": {
          "color": 30
        },
        "constant": "yellow",
        "constant.builtin": {
          "bold": true,
          "color": "yellow"
        },
        "constructor": 30,
        "embedded": null,
        "function": {
          "color": "blue"
        },
        "function.builtin": {
          "bold": true,
          "color": "blue"
        },
        "keyword": {
          "color": 35
        },
        "keyword.control": {
          "color": 35
        },
        "module": 30,
        "number": {
          "bold": true,
          "color": "yellow"
        },
        "operator": {
          "color": "white"
        },
        "property": 30,
        "property.builtin": {
          "bold": true,
          "color": 30
        },
        "punctuation": {
           "color": "white"
        },
        "punctuation.bracket": {
           "color": "white"
        },
        "punctuation.delimiter": {
           "color": "white"
        },
        "punctuation.special": {
           "color": "white"
        },
        "string": "green",
        "string.special": "green",
        "tag": 30,
        "type": "cyan",
        "type.builtin": {
          "bold": true,
          "color": "cyan"
        },
        "variable": 38,
        "variable.builtin": {
          "bold": true,
          "color": 38
        },
        "variable.parameter": {
          "color": 38
        }
      }
    }
  '';
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
    cat > $out/share/tree-sitter/config.json <<EOF
    ${tree-sitter-config "$out/share/tree-sitter"}
    EOF

    mkdir -p $out/share/tree-sitter/tree-sitter-lean
    cp -r ${tree-sitter-lean}/* $out/share/tree-sitter/tree-sitter-lean/

    mkdir -p $out/share/tree-sitter/tree-sitter-lean/queries
    cp highlights.scm $out/share/tree-sitter/tree-sitter-lean/queries/highlights.scm

    jq '.grammars[0].highlights = "queries/highlights.scm"' "$out/share/tree-sitter/tree-sitter-lean/tree-sitter.json" > "$out/share/tree-sitter/tree-sitter-lean/tree-sitter.json.tmp"
    mv "$out/share/tree-sitter/tree-sitter-lean/tree-sitter.json.tmp" "$out/share/tree-sitter/tree-sitter-lean/tree-sitter.json"

    mkdir -p $out/bin
    cp ansi_compress.py $out/bin/ansi_compress.py
    cp pretty.py $out/bin/pretty.py

    cat > $out/bin/lean-highlight <<EOF
    #!/usr/bin/env bash
    if [ "\$#" -lt 1 ]; then
      echo "Usage: lean-highlight <file>"
      exit 1
    fi
    # tree-sitter compiles parser sources into ~/.cache/tree-sitter on first run.
    export PATH="${pkgs.stdenv.cc}/bin:\$PATH"
    ${pkgs.tree-sitter}/bin/tree-sitter highlight "\$1" | \
      ${pkgs.python3}/bin/python3 -u $out/bin/ansi_compress.py
    EOF

    cat > $out/bin/lean-pretty <<EOF
    #!/usr/bin/env bash
    if [ "\$#" -lt 1 ]; then
      echo "Usage: lean-pretty <file>"
      exit 1
    fi
    $out/bin/lean-highlight "\$1" | \
      ${pkgs.python3}/bin/python3 -u $out/bin/pretty.py
    EOF

    chmod +x $out/bin/lean-highlight
    chmod +x $out/bin/lean-pretty
  '';
}
