{
  description = "Rust Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  };

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in
    {
      devShells = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          default = pkgs.mkShell {
            packages =
              (with pkgs; [
                alejandra
                bacon
                cargo
                cargo-audit
                cargo-bloat
                cargo-cross
                cargo-deny
                cargo-docset
                cargo-edit
                cargo-license
                cargo-make
                cargo-modules
                cargo-mutants
                cargo-nextest
                cargo-outdated
                cargo-spellcheck
                cargo-tarpaulin
                cargo-unused-features
                cargo-update
                cargo-watch
                clippy
                evcxr
                rust-analyzer
                rustc
                rustfmt
                taplo
              ])
              ++ nixpkgs.lib.optionals pkgs.stdenv.isLinux (with pkgs; [
                clang_18
                docker
                lld_18
                lldb_18
                mold
              ]);

            buildInputs = with pkgs; [
              openssl
              pkg-config
            ];

            shellHook = ''
              export OPENSSL_NO_VENDOR=1
              export OPENSSL_LIB_DIR="${nixpkgs.lib.getLib pkgs.openssl}/lib"
            '';
          };
        }
      );
    };
}
