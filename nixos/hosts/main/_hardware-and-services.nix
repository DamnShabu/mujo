{
  pkgs,
  self,
  lib,
  ...
}: {
  hardware.cpu.amd.updateMicrocode = true;

  services = {
    flatpak.enable = true;
    udisks2.enable = true;
    printing.enable = true;
    upower.enable = true;
    power-profiles-daemon.enable = true;
  };

  virtualisation.docker.enable = true;

  # Docker stays installed and fully functional; it just doesn't hold ~157 MB
  # resident from boot. The socket starts it on first use.
  virtualisation.docker.enableOnBoot = false;

  # The journal had grown to 3.6 GB: the default cap is 10% of the filesystem,
  # and /var/log lives on a 3.7 TB volume.
  services.journald.extraConfig = "SystemMaxUse=200M";

  # 5.3s of every boot, spent blocking network-online.target for a desktop that
  # has nothing ordered after it.
  systemd.services.NetworkManager-wait-online.enable = false;

  environment.localBinInPath = true;

  # zram is configured once, in nixos/core/system-preferences.nix (the host-level
  # duplicate of these two lines was dead). The 16G disk swap partition in
  # disko.nix stays as overflow and for hibernation via its resumeDevice.


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

  programs.niri = {
    enable = true;
    package = self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  };

  services.xserver.videoDrivers = ["amdgpu"];
  boot.initrd.kernelModules = ["amdgpu"];
}
