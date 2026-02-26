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
        "constant": 33,
        "constant.builtin": {
          "bold": true,
          "color": 33
        },
        "constructor": 36,
        "embedded": null,
        "function": {
          "color": 34
        },
        "function.builtin": {
          "bold": true,
          "color": 34
        },
        "keyword": {
          "color": 35
        },
        "keyword.control": {
          "color": 35
        },
        "module": 36,
        "number": {
          "bold": true,
          "color": 33
        },
        "operator": {
          "color": 37
        },
        "property": 33,
        "property.builtin": {
          "bold": true,
          "color": 33
        },
        "punctuation": {
           "color": 37
        },
        "punctuation.bracket": {
           "color": 37
        },
        "punctuation.delimiter": {
           "color": 37
        },
        "punctuation.special": {
           "color": 37
        },
        "string": 32,
        "string.special": 32,
        "tag": 35,
        "type": 36,
        "type.builtin": {
          "bold": true,
          "color": 36
        },
        "variable": 37,
        "variable.builtin": {
          "bold": true,
          "color": 37
        },
        "variable.parameter": {
          "color": 36
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
    cp semantic_highlight.py $out/bin/semantic_highlight.py
    cp mixed_highlight.py $out/bin/mixed_highlight.py

    cat > $out/bin/lean-highlight <<EOF
    #!/usr/bin/env bash
    mode="''${LEAN_HIGHLIGHT_MODE:-treesitter}"
    if [ "\$1" = "--semantic" ]; then
      mode="semantic"
      shift
    elif [ "\$1" = "--mixed" ]; then
      mode="mixed"
      shift
    elif [ "\$1" = "--auto" ]; then
      mode="auto"
      shift
    fi

    if [ "\$#" -lt 1 ]; then
      echo "Usage: lean-highlight [--semantic|--mixed|--auto] <file>"
      exit 1
    fi

    if [ "\$mode" = "semantic" ]; then
      exec ${pkgs.python3}/bin/python3 -u $out/bin/semantic_highlight.py "\$1"
    fi

    if [ "\$mode" = "mixed" ]; then
      # mixed = tree-sitter base + semantic token overlays when available.
      export PATH="${pkgs.stdenv.cc}/bin:${pkgs.tree-sitter}/bin:\$PATH"
      exec ${pkgs.python3}/bin/python3 -u $out/bin/mixed_highlight.py "\$1"
    fi

    if [ "\$mode" = "auto" ]; then
      if ${pkgs.python3}/bin/python3 -u $out/bin/semantic_highlight.py "\$1" 2>/dev/null; then
        exit 0
      fi
      # Fall back to syntax-only highlighting when Lean LSP is unavailable.
    fi

    # tree-sitter compiles parser sources into ~/.cache/tree-sitter on first run.
    export PATH="${pkgs.stdenv.cc}/bin:\$PATH"
    ${pkgs.tree-sitter}/bin/tree-sitter highlight "\$1" | \
      ${pkgs.python3}/bin/python3 -u $out/bin/ansi_compress.py
    EOF

    cat > $out/bin/lean-semantic-highlight <<EOF
    #!/usr/bin/env bash
    if [ "\$#" -lt 1 ]; then
      echo "Usage: lean-semantic-highlight <file>"
      exit 1
    fi
    exec ${pkgs.python3}/bin/python3 -u $out/bin/semantic_highlight.py "\$1"
    EOF

    cat > $out/bin/lean-mixed-highlight <<EOF
    #!/usr/bin/env bash
    if [ "\$#" -lt 1 ]; then
      echo "Usage: lean-mixed-highlight <file>"
      exit 1
    fi
    export PATH="${pkgs.stdenv.cc}/bin:${pkgs.tree-sitter}/bin:\$PATH"
    exec ${pkgs.python3}/bin/python3 -u $out/bin/mixed_highlight.py "\$1"
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
    chmod +x $out/bin/lean-semantic-highlight
    chmod +x $out/bin/lean-mixed-highlight
  '';
}
