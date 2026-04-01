{ lib, ... }:
let
  # Read the immediate children of `hosts/`.
  # Example shape:
  # {
  #   fermi = "directory";
  #   legion = "directory";
  #   vm = "directory";
  # }
  hostDirs = builtins.readDir ../hosts;
in
# Convert each host directory into a reusable module value under `self.hosts`.
lib.pipe hostDirs [
  # Step 1: keep only directory entries.
  # Output shape:
  # {
  #   fermi = "directory";
  #   legion = "directory";
  #   vm = "directory";
  # }
  (lib.filterAttrs (_name: type: type == "directory"))

  # Step 2: keep only the host names.
  # Output shape:
  # [ "fermi" "legion" "vm" ]
  lib.attrNames

  # Step 3: turn each host name into the `{ name, value }` shape expected by
  # `builtins.listToAttrs`.
  #
  # Input to the lambda:
  # - `name`: host name, like "vm"
  #
  # Output from the lambda:
  # - {
  #     name = "vm";
  #     value = ../hosts/vm/configuration.nix;
  #   }
  #
  # That `value` is the host's explicit module entrypoint.
  #
  # Host-specific configuration stays primitive on purpose: each host's
  # `configuration.nix` decides which neighboring files to import, instead of the
  # flake loader recursively pulling in every `*.nix` file under the host folder.
  (map (name: {
    inherit name;
    value = ../hosts/${name}/configuration.nix;
  }))

  # Step 4: convert the list of records into the final attrset.
  # Final output shape:
  # {
  #   fermi = <module attrset>;
  #   legion = <module attrset>;
  #   vm = <module attrset>;
  # }
  builtins.listToAttrs
]
