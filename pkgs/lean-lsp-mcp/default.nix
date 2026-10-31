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
    version = "0.13.2";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-MaypVPEGgFvIzClr7vOmzIAYB+FtSFMiv6gIgds2iS8=";
    };

    build-system = [ pythonPackages.hatchling ];

    dependencies = with pythonPackages; [
      orjson
      psutil
      tqdm
      watchfiles
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
  version = "0.32.0";
  pyproject = true;

  src = pkgs.fetchPypi {
    pname = "lean_lsp_mcp";
    inherit version;
    hash = "sha256-T59HHdyc/n/Yd8nNpwh3IWnRGWSgUmKTCTPInzEn8bY=";
  };

  build-system = [ pythonPackages.setuptools ];

  # Upstream pins MCP exactly and requires a newer certifi data release than
  # nixpkgs currently carries.  Neither constraint changes the APIs used here.
  pythonRelaxDeps = [
    "certifi"
    "mcp"
  ];

  dependencies = with pythonPackages; [
    certifi
    leanclient
    mcp
    orjson
    psutil
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
