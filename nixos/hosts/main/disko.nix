{
  flake.diskoConfigurations.hostMain = {
    disko.devices = {
      disk.main = {
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7DPNJ0Y311033P";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              name = "boot";
              size = "1M";
              type = "EF02";
            };
            esp = {
              name = "ESP";
              size = "2G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            swap = {
              size = "16G";
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };
            root = {
              name = "root";
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "btrfs_vg";
              };
            };
          };
        };
      };
      nodev = {
        "/" = {
          fsType = "tmpfs";
          mountOptions = [
            "size=25%"
            "mode=755"
          ];
        };
      };
      lvm_vg = {
        btrfs_vg = {
          type = "lvm_vg";
          lvs = {
            root = {
              size = "100%FREE";
              content = {
                type = "btrfs";
                extraArgs = ["-f"];

                subvolumes = {
                  "/root" = {
                    # mountpoint = "/";
                  };

                  "/persist" = {
                    mountOptions = ["subvol=persist" "noatime" "compress=zstd:1"];
                    mountpoint = "/persist";
                  };

                  "/nix" = {
                    # noatime: relatime existed only so the preload daemon could
                    # learn prefetch order from atime. preload is gone, so the
                    # store no longer needs access-time writes at all.
                    # zstd:1 is cheap and /nix is highly compressible.
                    mountOptions = ["subvol=nix" "noatime" "compress=zstd:1"];
                    mountpoint = "/nix";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
