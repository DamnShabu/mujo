{...}: {
  boot = {
    loader.grub.enable = true;
    loader.grub.efiSupport = true;
    loader.grub.efiInstallAsRemovable = true;

    supportedFilesystems.ntfs = true;

    kernelParams = ["quiet" "video=DP-1:1920x1080@165" "video=HDMI-A-1:1920x1080@60"];
    kernelModules = ["coretemp" "cpuid" "v4l2loopback"];

    binfmt.emulatedSystems = ["aarch64-linux"];

    # Limit kernels in /boot to prevent filling the partition
    loader.grub.configurationLimit = 5;

    # The GRUB menu was 5.45s of every boot — the second-largest stage after
    # firmware. 1s still leaves a window to hit a key and pick a generation.
    loader.timeout = 1;

    kernel.sysctl = {
      # Reclaim slab/inode caches more eagerly without hurting NVMe I/O performance
      "vm.vfs_cache_pressure" = 150;

      # Flush dirty write buffers sooner to keep active page cache lean
      "vm.dirty_background_ratio" = 5;
      "vm.dirty_ratio" = 10;

      # Disable watermark boost to eliminate kernel memory allocation spikes and fragmentation
      "vm.watermark_boost_factor" = 0;

      # Single-page cluster for compressed ZRAM swap
      "vm.page-cluster" = 0;
    };
  };
}
