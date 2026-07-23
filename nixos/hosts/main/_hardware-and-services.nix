{ pkgs, self, ... }: {
  hardware.cpu.amd.updateMicrocode = true;

  services = {
    flatpak.enable = true;
    udisks2.enable = true;
    printing.enable = true;
    upower.enable = true;
    power-profiles-daemon.enable = true;
  };

  programs.alvr.enable = true;
  programs.alvr.openFirewall = true;

  environment.systemPackages = with pkgs; [
    glib

    bs-manager

    zerotierone

    android-tools

    self.packages."${pkgs.stdenv.hostPlatform.system}".phisch-psst
  ];

  xdg.portal = {
    extraPortals = [pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-wlr];
    enable = true;
    config = {
      common = {
        default = ["gtk" "wlr"];
        "org.freedesktop.impl.portal.FileChooser" = "gtk";
        "org.freedesktop.impl.portal.OpenURI" = "gtk";
      };
    };
  };

  hardware.graphics.enable = true;

  programs.niri = {
    enable = true;
    package = self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  };

  services.xserver.videoDrivers = ["amdgpu"];
  boot.initrd.kernelModules = ["amdgpu"];

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-move-transition
    ];
  };

  persistence.cache.directories = [
    ".config/obs-studio"
  ];
}
