{
  description = "amber-lang and amber-lsp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        rustPlatform = pkgs.rustPlatform;

        amber-lsp = rustPlatform.buildRustPackage {
          pname = "amber-lsp";
          version = "0.1.16";

          src = pkgs.fetchFromGitHub {
            owner = "amber-lang";
            repo = "amber-lsp";
            rev = "v0.1.16";
            sha256 = "sha256-thQh+yShChds4S/2/rbxJGpRMqirCnC2dmx0StLJGmY=";
          };

          cargoHash = "sha256-yS0m2FCyqNztJXKRWye/II7lOg2H/DTQWXScxz5vO8k=";

          postPatch = ''
            substituteInPlace crates/analysis/src/stdlib.rs \
              --replace 'fn get_stdlib_dir(amber_version: AmberVersion) -> Result<PathBuf, std::io::Error> {
    let amber_subdir = match amber_version {
        AmberVersion::Alpha034 => "alpha034",
        AmberVersion::Alpha035 => "alpha035",
        AmberVersion::Alpha040 => "alpha040",
        AmberVersion::Alpha050 => "alpha050",
    };

    Ok(current_exe()?
        .parent()
        .unwrap()
        .to_path_buf()
        .join("amber-lsp-resources")
        .join(amber_subdir))
}' \
          'fn get_stdlib_dir(amber_version: AmberVersion) -> Result<PathBuf, std::io::Error> {
                let amber_subdir = match amber_version {
                    AmberVersion::Alpha034 => "alpha034",
                    AmberVersion::Alpha035 => "alpha035",
                    AmberVersion::Alpha040 => "alpha040",
                    AmberVersion::Alpha050 => "alpha050",
                };

                let base = std::env::var_os("XDG_DATA_HOME")
                    .map(std::path::PathBuf::from)
                    .unwrap_or_else(|| {
                        std::env::var_os("HOME")
                            .map(|h| std::path::PathBuf::from(h).join(".local/share"))
                            .unwrap_or_else(|| std::path::PathBuf::from("."))
                    })
                    .join("amber-lsp")
                    .join("amber-lsp-resources");

                Ok(base.join(amber_subdir))
            }';
          '';


          meta = {
            description = "Amber Language Server";
          };
        };

      in {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.amber-lang
            amber-lsp
          ];
        };
      });
}