{ lib, myLib, ... }:
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
  #     value = { imports = [ ... ]; };
  #   }
  #
  # That `value` is itself a NixOS module.
  # More specifically, it is a combined module whose only job is to import all
  # the host-specific module files from `hosts/<name>/`.
  (map (name: {
    inherit name;
    value = {
      # Recursively import all `.nix` files in this host folder so a host can be
      # split across `configuration.nix`, `hardware-configuration.nix`, and any
      # smaller host-specific files.
      imports = myLib.recursivelyImport [ ../hosts/${name} ];
    };
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
