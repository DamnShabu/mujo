{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.main = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.hostMain
    ];
  };

  flake.nixosModules.hostMain = {
    pkgs,
    config,
    lib,
    ...
  }: {
    imports = [
      self.nixosModules.base
      self.nixosModules.general
      self.nixosModules.desktop

      self.nixosModules.impermanence

      self.nixosModules.flatpak

      self.nixosModules.opencode
      self.nixosModules.discord
      self.nixosModules.gimp
      self.nixosModules.obsidian
      self.nixosModules.steam
      self.nixosModules.telegram
      self.nixosModules.gaming
      self.nixosModules.virt
      self.nixosModules.searxng
      self.nixosModules.user-config
      self.nixosModules.user
      self.nixosModules.sops
      self.nixosModules.keys
      self.nixosModules.mullvad
      self.nixosModules.connections
      self.nixosModules.notifications

      self.nixosModules.quickshell

      self.nixosModules.extra_plymouth

      # disko
      inputs.disko.nixosModules.disko
      self.diskoConfigurations.hostMain

      # flatpak management
      inputs.nix-flatpak.nixosModules.nix-flatpak

    ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

    programs.corectrl.enable = true;

    boot = {
      loader.grub.enable = true;
      loader.grub.efiSupport = true;
      loader.grub.efiInstallAsRemovable = true;

      supportedFilesystems.ntfs = true;

      kernelParams = ["quiet" "video=DP-1:1920x1080@165" "video=HDMI-A-1:1920x1080@60"];
      kernelModules = ["coretemp" "cpuid" "v4l2loopback"];

      binfmt.emulatedSystems = ["aarch64-linux"];
    };

    networking = {
      hostName = lib.mkDefault "main";
      networkmanager.enable = true;
    };

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

    networking.firewall.enable = true;
    programs.appimage.enable = true;
    programs.appimage.binfmt = true;

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


    system.stateVersion = "25.11";
  };
}
