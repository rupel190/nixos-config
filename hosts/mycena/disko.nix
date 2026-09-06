# Declarative disk layout for mycena (Surface Book 1, 238 GiB Samsung NVMe).
#
# DESTRUCTIVE: disko owns /dev/nvme0n1 end to end and writes a fresh GPT. The
# Windows install and the old Ubuntu 17.10 rootfs that shipped on this disk are
# both wiped on first apply — deliberate, there was nothing to keep.
#
# `priority` fixes partition ORDER on the device; without it disko falls back to
# alphabetical (esp, root, swap), which would place the 100%-sized root before
# swap and leave swap nowhere to go.
{
  disko.devices.disk.main = {
    device = "/dev/nvme0n1";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        esp = {
          priority = 1;
          name = "ESP";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            # Root-only: the ESP holds unencrypted kernels and initrds, and
            # vfat has no permission bits of its own to lean on.
            mountOptions = [ "umask=0077" ];
          };
        };

        # Real swap on top of zramSwap: 8 GiB RAM is enough to OOM while
        # building, and zram alone cannot back hibernation or heavy overcommit.
        swap = {
          priority = 2;
          size = "8G";
          content = {
            type = "swap";
            discardPolicy = "both";
          };
        };

        root = {
          priority = 3;
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
