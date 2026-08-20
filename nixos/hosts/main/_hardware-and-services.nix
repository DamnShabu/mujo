{ pkgs, self, lib, ... }: {
  hardware.cpu.amd.updateMicrocode = true;

  services = {
    flatpak.enable = true;
    udisks2.enable = true;
    printing.enable = true;
    upower.enable = true;
    power-profiles-daemon.enable = true;
  };

  virtualisation.docker.enable = true;

  # Compressed RAM swap. Layering: zram (priority 5, the module default) fills
  # first for cheap reclaim of cold pages; the 16G disk swap partition
  # (disko.nix) stays as overflow and for hibernation via its resumeDevice.
  # memoryPercent can be tuned after checking `zramctl` for actual usage.
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;

  environment.systemPackages = with pkgs; [
    glib

    zerotierone

    android-tools

    self.packages."${pkgs.stdenv.hostPlatform.system}".phisch-psst
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
