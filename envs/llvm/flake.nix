{
  description = "LLVM env";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        gccForLibs = pkgs.stdenv.cc.cc;
        # Build scripts as packages so they can be exposed as apps
        build-llvm-pkg = pkgs.writeShellApplication {
          name = "build-llvm";
          runtimeInputs = with pkgs; [ cmake ninja mold clang clang-tools zlib ];
          text = ''
            set -e

            if [ "$#" -ne 1 ]; then
              echo "Usage: $0 <path_to_llvm_source>"
              exit 1
            fi

            src="$PWD/$1/llvm"

            # Create an out-of-source build directory: build/llvm
            build_dir="$PWD/build/llvm"
            mkdir -p "$build_dir"

            # where to find libgcc
            export NIX_LDFLAGS="-L${gccForLibs}/lib/gcc/${pkgs.targetPlatform.config}/${gccForLibs.version}"
            # teach clang about C startup file locations
            export CFLAGS="-B${gccForLibs}/lib/gcc/${pkgs.targetPlatform.config}/${gccForLibs.version} -B ${pkgs.stdenv.cc.libc}/lib"

            cmakeFlags=(
                "-GNinja"
                "-DCMAKE_BUILD_TYPE=Debug"
                 # inst will be our installation prefix
                "-DCMAKE_INSTALL_PREFIX=../inst"
                # this makes llvm only to produce code for the given platforms, this saves CPU time, change it to what you need
                "-DLLVM_TARGETS_TO_BUILD=host;RISCV;AArch64;X86"
                # Projects to build
                "-DLLVM_ENABLE_PROJECTS=clang"
                # Faster linker
                "-DLLVM_USE_LINKER=mold"
                # Dynamic Linking
                "-DBUILD_SHARED_LIBS=ON"
                # Prevents debug info duplication, which also speeds up the linker
                # Also improves incremental building speed
                "-DLLVM_USE_SPLIT_DWARF=ON"
                # Optimized TableGen since we're not developing that
                # Also speeds up build time since llvm-tblgen will run faster
                "-DLLVM_OPTIMIZED_TABLEGEN=ON"
                # Newer PassManager (faster compilation speed)
                "-DLLVM_USE_NEWPM=ON"
                "-DLLVM_ENABLE_ASSERTIONS=ON"
                "-DLLVM_ENABLE_EH=ON"
                "-DLLVM_ENABLE_RTTI=ON"
            )
            # Run CMake inside build/llvm
            cd "$build_dir"
            cmake "''${cmakeFlags[@]}" "$src"
            ninja
          '';
        };

        build-alive-pkg = pkgs.writeShellApplication {
          name = "build-alive";
          runtimeInputs = with pkgs; [ cmake ninja ];
          text = ''
            set -e

            if [ "$#" -ne 2 ]; then
              echo "Usage: $0 <path_to_alive_source> <path_to_llvm_build>"
              exit 1
            fi

            alive2SourceDir="$PWD/$1"
            llvmBuildSourceDir="$PWD/$2"

            # Create an out-of-source build directory: build/alive
            build_dir="$PWD/build/alive"
            mkdir -p "$build_dir"

            cmakeFlags=(
                -GNinja
                -DCMAKE_BUILD_TYPE=Debug
                -DCMAKE_PREFIX_PATH="$llvmBuildSourceDir" -DBUILD_TV=1
            )
            # Run CMake inside build/alive
            cd "$build_dir"
            cmake "''${cmakeFlags[@]}" "$alive2SourceDir"
            ninja
          '';
        };
      in
      with pkgs;
      {
        packages.build-llvm = build-llvm-pkg;
        packages.build-alive = build-alive-pkg;

        apps.build-llvm = {
          type = "app";
          program = "${self.packages.${system}.build-llvm}/bin/build-llvm";
        };
        apps.build-alive = {
          type = "app";
          program = "${self.packages.${system}.build-alive}/bin/build-alive";
        };

        devShells.default = mkShell {
          packages = [ build-llvm-pkg build-alive-pkg ];
          buildInputs = [
            gccForLibs # C/C++ compiler
            cmake # CMake for build configuration
            ninja # Ninja build system for faster builds
            python3 # Python 3.x
            bashInteractive # Linux shell
            zlib # zlib for compression support
            #llvmPackages_latest.llvm  # LLVM packages
            #llvmPackages.mlir # For TableGen LSP
            mold # Faster linker
            clang-tools # LSP
            clang

            # Alive dependencies
            z3
            re2c
          ];
          # where to find libgcc
          NIX_LDFLAGS = "-L${gccForLibs}/lib/gcc/${targetPlatform.config}/${gccForLibs.version}";
          # teach clang about C startup file locations
          CFLAGS = "-B${gccForLibs}/lib/gcc/${targetPlatform.config}/${gccForLibs.version} -B ${stdenv.cc.libc}/lib";

          shellHook = ''
            export PATH=$PWD/llvm-project/clang/tools/clang-format:$PATH
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ zlib ]}:$LD_LIBRARY_PATH"
            export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib.outPath}/lib:$LD_LIBRARY_PATH"
          '';
        };
      }
    );
}
