# Boot nixosConfigurations.main as a REAL installed system, in a throwaway VM.
#
# Unlike `nixos-rebuild build-vm`, this runs disko for real: it formats disks to
# the layout in nixos/hosts/main/disko.nix, installs the system onto them, then
# boots that. So the tmpfs root, the btrfs subvolumes, the LVM volume group and
# the random-key swap are all exercised. That is the difference between a test
# that proves the storage model and one that quietly replaces it with ext4.
#
# NOT part of the flake. `tests/` is outside the importTree roots, so this file
# is only ever evaluated when you ask for it by path. See AGENTS.md > COMMANDS.
#
# What it does NOT test: the bootloader. qemu boots the kernel directly, so
# /boot stays empty and no system profile generation is created. Test failures
# about missing generations are artifacts of the method, not the config.
{
  config,
  lib,
  pkgs,
  ...
}: let
  tests = ./..;
  me = config.preferences.user.name;
in {
  # The real device is a 4 TB NVMe; the image only has to hold the ESP, swap and
  # enough btrfs for /persist. qcow2 is sparse, so this does not cost 40 GB.
  disko.devices.disk.main.imageSize = lib.mkForce "40G";
  disko.memSize = 6144;

  # disko's image builder hands vmTools an aggregated module tree as `kernel`,
  # and current nixpkgs refuses that unless `kernelImage` names the bootable
  # file inside it. Scoped to the image builder so the system being installed is
  # not rebuilt against a patched nixpkgs.
  disko.imageBuilder.pkgs = pkgs.extend (_final: prev: {
    vmTools = prev.vmTools.override {kernelImage = "bzImage";};
  });

  # Merged into the VM variant only, never into the base configuration.
  disko.tests.extraConfig = {
    # Flip to true for a QEMU window with the real Niri/Quickshell session
    # instead of a serial console in this terminal.
    virtualisation.graphics = false;
    virtualisation.cores = 4;
    virtualisation.qemu.options = ["-cpu host"];

    # The host reads its login hash from /persist/passwd, which a freshly
    # formatted disk does not have. This override exists only inside this VM --
    # the real machine's credentials are never touched.
    users.users.root.password = lib.mkForce "vmtest";
    users.users.${me} = {
      hashedPasswordFile = lib.mkForce null;
      password = lib.mkForce "vmtest";
    };
    services.getty.autologinUser = lib.mkForce "root";

    systemd.services.mujo-acceptance = {
      description = "Mujo security acceptance suite";
      wantedBy = ["multi-user.target"];
      after = ["multi-user.target" "mujo-trustd.socket"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # As the user, not root: the suite asks whether an *unprivileged*
        # process can cross a boundary, and root crosses most of them by
        # definition. Run it as root and it reports breaches that are not real.
        User = me;
        Group = "users";
        StandardOutput = "journal+console";
        StandardError = "journal+console";
        WorkingDirectory = "/tmp";
      };
      # The system path, or every `command -v mujo-*` reports "not installed"
      # and the containment checks all skip into a falsely green run.
      environment.PATH =
        lib.mkForce
        "/run/wrappers/bin:/run/current-system/sw/bin:${lib.makeBinPath (with pkgs; [jq socat])}";
      script = ''
        echo "########## MUJO ACCEPTANCE START ##########"
        ${pkgs.bash}/bin/bash ${tests}/run-all-tests.sh || true
        echo "########## MUJO ACCEPTANCE END ##########"
      '';
    };
  };
}
