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
    version = "0.9.4";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-AaFOGSWcrbofbAKnBAihGJtNk9bwZo88cFFFLpmNBLU=";
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
  version = "0.25.1";
  pyproject = true;

  src = pkgs.fetchPypi {
    pname = "lean_lsp_mcp";
    inherit version;
    hash = "sha256-Urmv/UXBjsiX38vGJmr6GP/pqkFH8ptut5AtCraBBBw=";
  };

  build-system = [ pythonPackages.setuptools ];

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
