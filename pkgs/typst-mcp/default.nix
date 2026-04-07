{
  lib,
  pkgs,
  ...
}:
let
  pythonPackages = pkgs.python3Packages;

  mcp = pythonPackages.buildPythonPackage rec {
    pname = "mcp";
    version = "1.8.0";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-Jj37cAVAtybAk/DD4EP2at7Qcw0LUfBOsKPrkAVf5Js=";
    };

    build-system = with pythonPackages; [
      hatchling
      uv-dynamic-versioning
    ];

    dependencies = with pythonPackages; [
      anyio
      httpx
      httpx-sse
      pydantic
      pydantic-settings
      python-multipart
      sse-starlette
      starlette
      uvicorn
    ];

    pythonImportsCheck = [ "mcp" ];

    meta = {
      description = "Official Python SDK for Model Context Protocol servers and clients";
      homepage = "https://github.com/modelcontextprotocol/python-sdk";
      license = lib.licenses.mit;
    };
  };

  python = pkgs.python3.withPackages (
    ps: [
      mcp
      ps.numpy
      ps.pillow
    ]
  );

  typstDocsCli = pkgs.rustPlatform.buildRustPackage {
    pname = "typst-docs";
    version = pkgs.typst.version;

    src = pkgs.typst.src;
    cargoHash = pkgs.typst.cargoHash;
    cargoBuildFlags = [ "-p" "typst-docs" ];
    doCheck = false;

    meta = {
      description = "CLI for exporting the Typst documentation as JSON";
      homepage = "https://github.com/typst/typst";
      license = lib.licenses.asl20;
      mainProgram = "typst-docs";
      platforms = lib.platforms.unix;
    };
  };

  typstDocs = pkgs.runCommand "typst-docs-${pkgs.typst.version}" {
    nativeBuildInputs = [ typstDocsCli ];
  } ''
    mkdir -p "$out/assets"
    typst-docs \
      --assets-dir "$out/assets" \
      --out-file "$out/main.json"
  '';
in
pkgs.stdenvNoCC.mkDerivation rec {
  pname = "typst-mcp";
  version = "0.1.0-unstable-2026-04-06";

  src = pkgs.fetchFromGitHub {
    owner = "johannesbrandenburger";
    repo = "typst-mcp";
    rev = "e4248a761ebad39afdbe8e1a4065bb84401d37bd";
    hash = "sha256-0NGIOsvpz5KmhemCEyCNtbRMa9gb4Y9oGUbBjWDKKjU=";
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    dataDir="$out/share/${pname}"
    mkdir -p "$out/bin" "$dataDir/typst-docs"

    cp "$src/server.py" "$dataDir/server.py"
    cp "$src/typst-docs-json-schema.json" "$dataDir/"
    cp -r ${typstDocs}/. "$dataDir/typst-docs/"

    sed -i '/^import io$/a import sys' "$dataDir/server.py"

    makeWrapper "${python}/bin/python" "$out/bin/typst-mcp" \
      --add-flags "$dataDir/server.py" \
      --prefix PATH : "${lib.makeBinPath [ pkgs.pandoc pkgs.typst ]}"

    runHook postInstall
  '';

  meta = {
    description = "MCP server for Typst docs, validation, conversion, and rendering";
    homepage = "https://github.com/johannesbrandenburger/typst-mcp";
    license = lib.licenses.mit;
    mainProgram = "typst-mcp";
    platforms = lib.platforms.unix;
  };
}
