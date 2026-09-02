{
  pkgs,
  self,
  lib,
  ...
}: {
  hardware.cpu.intel.updateMicrocode = true;

  services = {
    flatpak.enable = true;
    udisks2.enable = true;
    printing.enable = true;
    upower.enable = true;
    power-profiles-daemon.enable = true;
  };

  # Daemonless container engine: 0 MB idle memory overhead, rootless by default,
  # crun + conmon C-based runtime, with transparent `docker` CLI compatibility.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # The journal had grown to 3.6 GB: the default cap is 10% of the filesystem,
  # and /var/log lives on a 3.7 TB volume.
  services.journald.extraConfig = "SystemMaxUse=200M";

  # 5.3s of every boot, spent blocking network-online.target for a desktop that
  # has nothing ordered after it.
  systemd.services.NetworkManager-wait-online.enable = false;

  # Monitor user session slices for runaway memory pressure and kill runaway
  # cgroups before the machine locks up or thrashes swap.
  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
  };

  systemd.user.slices."app.slice" = {
    sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "50%";
    };
  };

  environment.localBinInPath = true;

  # zram is configured once, in nixos/core/system-preferences.nix (the host-level
  # duplicate of these two lines was dead). The 16G disk swap partition in
  # disko.nix stays as overflow only; it is encrypted with a per-boot random
  # key, which rules out hibernation (no stable key to resume under).

  environment.systemPackages = with pkgs; [
    glib

    zerotierone

    android-tools

    nodejs
    bun
    tmux

    rtk
  ];

  xdg.portal = {
    extraPortals = [pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-gnome];
    enable = true;
    config = {
      common = {
        default = ["gnome" "gtk"];
        "org.freedesktop.impl.portal.FileChooser" = "gtk";
        "org.freedesktop.impl.portal.OpenURI" = "gtk";
      };
      niri = {
        default = lib.mkForce ["gnome" "gtk"];
        "org.freedesktop.impl.portal.FileChooser" = "gtk";
        "org.freedesktop.impl.portal.OpenURI" = "gtk";
        "org.freedesktop.impl.portal.ScreenCast" = ["gnome"];
        "org.freedesktop.impl.portal.Screenshot" = ["gnome"];
      };
    };
  };

  # SDDM's Qt greeter runs in its own user session (uid 175) and reaches for
  # xdg-desktop-portal to read the colour scheme. That session has no
  # compositor and no DISPLAY, so the gtk backend dies with "cannot open
  # display:" five times and hits its start limit on every boot, while the
  # gnome backend logs a dependency failure for each attempt. The greeter has
  # never actually got a portal out of this; skip the units there rather than
  # let them flap. The real session (uid 1000) activates portals only after
  # niri has exported WAYLAND_DISPLAY, and is unaffected.
  systemd.user.services =
    lib.genAttrs [
      "xdg-desktop-portal"
      "xdg-desktop-portal-gtk"
      "xdg-desktop-portal-gnome"
    ] (_: {
      overrideStrategy = "asDropin";
      unitConfig.ConditionUser = "!sddm";
    });

  programs.niri = {
    enable = true;
    package = self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  };

  services.xserver.videoDrivers = ["amdgpu"];
  boot.initrd.kernelModules = ["amdgpu"];
}
