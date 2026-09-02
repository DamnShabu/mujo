{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  # Secure Boot is off by default because turning it on swaps the bootloader,
  # which is the one change in this repo that can leave the machine unable to
  # start. Flip security.mujo.boot.secureBoot to true only after working through
  # docs/physical-security.md section 2a, which sequences key creation, an
  # unenforced test boot, and firmware enrolment so each step is reversible.
  secureBoot = config.security.mujo.boot.secureBoot;
in {
  imports = [inputs.lanzaboote.nixosModules.lanzaboote];

  boot = {
    # GRUB: the current, known-good bootloader. Its weakness is real — the menu
    # cannot be locked, so anyone at the keyboard can press "e", append
    # init=/bin/sh and get root without a password. That is what Secure Boot
    # below closes; until it is enabled, treat physical access as root access.
    loader.grub = {
      enable = lib.mkDefault (!secureBoot);
      efiSupport = true;
      # Mutually exclusive with canTouchEfiVariables, so both track secureBoot.
      efiInstallAsRemovable = !secureBoot;
      # Limit kernels in /boot to prevent filling the partition
      configurationLimit = 5;

      # install-grub.pl copies kernels to the ESP with copy+rename and never
      # fsyncs, then skips any destination that already exists ("if (! -e
      # $dst)"). On vfat the rename can reach disk before the 84MB of initrd
      # data does, so a hard reset in that window leaves a full-size directory
      # entry with no content: fsck truncates it to 0 and parks the orphaned
      # clusters in /boot/FSCK*.REC. The entry still "exists", so no later
      # rebuild repairs it and that generation is silently unbootable until you
      # pick it from the menu. That is how configuration 793 died.
      #
      # Both grub hooks run after the copy pass -- extraPrepareConfig is invoked
      # at install-grub.pl:618, well past the copyToKernelsDir calls -- so this
      # rewrites the bad bytes itself instead of deleting and waiting for a
      # re-copy that would never come. It only ever overwrites a file that
      # already disagrees with its store original, and never removes one it
      # cannot replace, so the worst case is a redundant copy. `set -e` in the
      # generated installer means a failure aborts the install and leaves the
      # working bootloader untouched.
      extraInstallCommands = ''
        for f in /boot/kernels/*-bzImage /boot/kernels/*-initrd; do
          [ -e "$f" ] || continue
          n=''${f##*/}
          case "$n" in
            *-bzImage) src=/nix/store/''${n%-bzImage}/bzImage ;;
            *-initrd)  src=/nix/store/''${n%-initrd}/initrd ;;
            *) continue ;;
          esac
          # A garbage-collected kernel cannot be sourced again. Keep whatever
          # copy /boot still holds rather than destroying a bootable entry.
          [ -e "$src" ] || continue
          # ponytail: size comparison, not a hash. Truncation is the failure
          # mode this actually sees, and hashing every kept generation would
          # read ~350MB on every rebuild. Move to sha256 if silent bit rot
          # ever turns up.
          if [ "$(${pkgs.coreutils}/bin/stat -c%s "$f")" = "$(${pkgs.coreutils}/bin/stat -c%s "$src")" ]; then
            continue
          fi
          echo "install-grub: /boot copy of $n is corrupt, restoring from $src"
          ${pkgs.coreutils}/bin/cp "$src" "$f.tmp"
          ${pkgs.coreutils}/bin/sync "$f.tmp"
          ${pkgs.coreutils}/bin/mv "$f.tmp" "$f"
        done

        # Orphaned clusters fsck salvaged out of a truncated kernel. Nothing
        # reads them and they cost 84MB of a 1GB partition.
        ${pkgs.coreutils}/bin/rm -f /boot/FSCK*.REC

        # The other half of the fix: flush the ESP now, so the next hard reset
        # cannot truncate a kernel this very rebuild just wrote.
        ${pkgs.coreutils}/bin/sync -f /boot
      '';
    };

    # lanzaboote installs a systemd-boot-compatible EFI stub signed with our own
    # PKI, so the firmware refuses any boot chain we did not produce. It signs at
    # activation time: with no keys in /var/lib/sbctl, `nixos-rebuild switch`
    # fails during bootloader install and leaves the installed bootloader
    # untouched — a missing key bundle cannot by itself brick the machine.
    lanzaboote = {
      enable = secureBoot;
      pkiBundle = "/var/lib/sbctl";
    };

    # lanzaboote takes systemd-boot's place; both cannot install at once. It
    # still reads the systemd-boot options below for the loader it generates.
    loader.systemd-boot.enable = lib.mkForce false;
    loader.systemd-boot.configurationLimit = 5;
    loader.efi.canTouchEfiVariables = secureBoot;

    supportedFilesystems.ntfs = true;

    kernelParams = ["quiet" "video=DP-1:1920x1080@165" "video=HDMI-A-1:1920x1080@60"];
    kernelModules = ["coretemp" "cpuid" "v4l2loopback"];

    binfmt.emulatedSystems = ["aarch64-linux"];

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
