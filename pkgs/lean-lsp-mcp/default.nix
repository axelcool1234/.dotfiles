{
  lib,
  pkgs,
  ...
}:
let
  python = pkgs.python3;
  pythonPackages = python.pkgs;

  leanclient = pythonPackages.buildPythonPackage rec {
    pname = "leanclient";
    version = "0.11.0";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-5RhBiQ37sDxBil5k8cu6A6+Lo3qYQhEQX2O1aBj7AlY=";
    };

    build-system = [ pythonPackages.hatchling ];

    dependencies = with pythonPackages; [
      orjson
      psutil
      tqdm
    ];

    pythonImportsCheck = [ "leanclient" ];

    meta = {
      description = "Python client for the Lean 4 language server";
      homepage = "https://github.com/oOo0oOo/leanclient";
      license = lib.licenses.mit;
    };
  };
in
pythonPackages.buildPythonApplication rec {
  pname = "lean-lsp-mcp";
  version = "0.27.0";
  pyproject = true;

  src = pkgs.fetchPypi {
    pname = "lean_lsp_mcp";
    inherit version;
    hash = "sha256-oeX9SLnFlo0emhoqjUV5h3DHj4AGhAaRwVCsc4GImXo=";
  };

  build-system = [ pythonPackages.setuptools ];

  # Upstream currently pins `mcp` to an exact patch version, while nixpkgs is
  # already on a nearby compatible patch release.
  pythonRelaxDeps = [ "mcp" ];

  dependencies = with pythonPackages; [
    certifi
    leanclient
    mcp
    orjson
    pyyaml
  ];

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      pkgs.elan
      pkgs.git
      pkgs.ripgrep
    ])
  ];

  pythonImportsCheck = [ "lean_lsp_mcp" ];

  meta = {
    description = "Model Context Protocol server for Lean theorem prover projects";
    homepage = "https://github.com/oOo0oOo/lean-lsp-mcp";
    license = lib.licenses.mit;
    mainProgram = "lean-lsp-mcp";
    platforms = lib.platforms.unix;
  };
}
