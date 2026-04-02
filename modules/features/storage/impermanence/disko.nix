{ config, inputs, lib, ... }:
let
  cfg = config.preferences.impermanence;
  efiMountPoint = config.preferences.grub.efiSysMountPoint;
in
{
  imports = [ inputs.disko.nixosModules.disko ];

  config = lib.mkIf cfg.enable {
    disko.devices.disk.main = {
      type = "disk";
      device = cfg.diskDevice;

      content = {
        type = "gpt";
        partitions = {
          ESP = {
            name = "boot";
            size = cfg.bootPartitionSize;
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = efiMountPoint;
              mountOptions = [ "umask=0077" ];
            };
          };

          swap = {
            name = "swap";
            size = cfg.swapSize;
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };

          root = {
            name = "nixos";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                root = {
                  mountpoint = "/";
                  mountOptions = cfg.mountOptions;
                };

                nix = {
                  mountpoint = "/nix";
                  mountOptions = cfg.mountOptions;
                };

                persist = {
                  mountpoint = "/persist";
                  mountOptions = cfg.mountOptions;
                };
              }
              // lib.optionalAttrs (cfg.homeSubvolume != null) {
                ${cfg.homeSubvolume} = {
                  mountpoint = "/home";
                  mountOptions = cfg.mountOptions;
                };
              };
            };
          };
        };
      };
    };

    fileSystems."/".neededForBoot = true;
    fileSystems."/nix".neededForBoot = true;
    fileSystems."/persist".neededForBoot = true;
  };
}
