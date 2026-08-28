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
  };
}
