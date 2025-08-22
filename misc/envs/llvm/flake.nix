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
      in
      with pkgs;
      {
        devShells.default = mkShell {
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
          ];
          # where to find libgcc
          NIX_LDFLAGS = "-L${gccForLibs}/lib/gcc/${targetPlatform.config}/${gccForLibs.version}";
          # teach clang about C startup file locations
          CFLAGS = "-B${gccForLibs}/lib/gcc/${targetPlatform.config}/${gccForLibs.version} -B ${stdenv.cc.libc}/lib";

          # To run this script in the terminal, type '$buildScript/bin/build-llvm <path_to_llvm_source>'
          # Example (if we're in the build folder): $buildScript/bin/build-llvm ../llvm-project/llvm
          buildScript = pkgs.writeShellScriptBin "build-llvm" ''
            #!/bin/bash
            set -e  # Exit on error

            # Check if a directory argument is provided
            if [ "$#" -ne 1 ]; then
              echo "Usage: $0 <path_to_llvm_source>"
              exit 1
            fi

            llvmSourceDir="$1"

            cmakeFlags=(
                "-DGCC_INSTALL_PREFIX=${gccForLibs}"
                "-DC_INCLUDE_DIRS=${stdenv.cc.libc.dev}/include"
                "-GNinja"
                # Debug for debug builds
                "-DCMAKE_BUILD_TYPE=Debug"
                # inst will be our installation prefix
                "-DCMAKE_INSTALL_PREFIX=../inst"
                # this makes llvm only to produce code for the current platform, this saves CPU time, change it to what you need
                "-DLLVM_TARGETS_TO_BUILD=host;RISCV;AArch64;X86"
                # Projects to build
                "-DLLVM_ENABLE_PROJECTS=llvm;mlir"
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

                # The following is for developing applications using LLVM/MLIR
                # For debugging applications
                -DLLVM_ENABLE_ASSERTIONS=ON 
                # For applications that use C++ Exceptions
                -DLLVM_ENABLE_EH=ON
                # For applications that use Run-Time Type Information
                -DLLVM_ENABLE_RTTI=ON
            )
            # Call cmake with the flags
            cmake "''${cmakeFlags[@]}" "$llvmSourceDir" 
          '';
          shellHook = ''
            export PATH=$PWD/llvm-project/clang/tools/clang-format:$PATH
            export PATH=$PWD/build:$PATH
            export PATH=$PWD/build/bin:$PATH
            export HELIX_RUNTIME="$PWD/runtime"
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ zlib ]}:$LD_LIBRARY_PATH"
            export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib.outPath}/lib:$LD_LIBRARY_PATH"
          '';
        };
      }
    );
}
