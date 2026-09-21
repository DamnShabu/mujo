{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.desktop = {
    pkgs,
    config,
    lib,
    ...
  }: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [
      self.nixosModules.gtk
      self.nixosModules.pipewire
      self.nixosModules.zen
      inputs.thyx.nixosModules.default
    ];

    # ── niri Wayland compositor ───────────────────────────────────────────────
    # This wires:
    #   - niri into services.displayManager.sessionPackages (so the greeter can
    #     discover and launch it),
    #   - xdg-desktop-portal + recommended portals,
    #   - services.graphical-desktop.enable → graphical-session.target in the
    #     user systemd instance (so user services can declare their dependencies).
    # ── display manager : SDDM ─────────────────────────────────────────────────
    services.xserver.enable = true;

    services.displayManager.sddm = {
      enable = true;
      thyx.enable = true;
    };

    services.displayManager.autoLogin = {
      enable = true;
      user = config.preferences.user.name;
    };
    services.displayManager.defaultSession = "niri";

    systemd.services.display-manager.environment.QML_IMPORT_PATH = "${pkgs.qt6.qt5compat}/lib/qt-6/qml";

    services.displayManager.enable = true;

    # ── GUI session environment ────────────────────────────────────────────────
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
      DEFAULT_BROWSER = "helium";
      BROWSER = "helium";

      XDG_CURRENT_DESKTOP = "niri:GNOME";
    };

    # ── packages ──────────────────────────────────────────────────────────────
    environment.systemPackages = [
      selfpkgs.terminal
      pkgs.wl-clipboard
      pkgs.cliphist
      pkgs.xdg-utils
      pkgs.gparted
      pkgs.nautilus
    ];

    services.gvfs.enable = true;

    # NixOS turns speech-dispatcher on by default; nothing here uses TTS, and it
    # drags in espeak-ng -> mbrola-voices (645 MB) plus a resident user daemon.
    services.speechd.enable = false;

    # ── fonts ─────────────────────────────────────────────────────────────────
    fonts.packages = with pkgs; [
      fira-code
      nerd-fonts.jetbrains-mono
      ubuntu-sans
      cm_unicode
      corefonts
      unifont
      material-symbols
    ];

    fonts.fontconfig = {
      enable = true;
      antialias = true;
      hinting = {
        enable = true;
        style = "slight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
      defaultFonts = {
        serif = ["Ubuntu Sans"];
        sansSerif = ["Ubuntu Sans"];
        monospace = ["Fira Code" "JetBrainsMono Nerd Font"];
      };
    };

    # ── locale ────────────────────────────────────────────────────────────────
    time.timeZone = lib.mkDefault config.preferences.locale.timeZone;
    i18n.defaultLocale = lib.mkDefault config.preferences.locale.default;

    # ── desktop file associations (XDG) ───────────────────────────────────────
    xdg.mime = {
      enable = true;
      defaultApplications = {
        "text/html" = ["helium.desktop"];
        "x-scheme-handler/http" = ["helium.desktop"];
        "x-scheme-handler/https" = ["helium.desktop"];
        "application/pdf" = ["helium.desktop"];
        "text/markdown" = ["md.obsidian.Obsidian.desktop"];
        # kitty.desktop declares no MimeType and takes no file argument, so
        # every consumer that validates the handler (xdg-desktop-portal, GIO)
        # rejects it and falls back to an "Open With" chooser. kitty-open is
        # the entry kitty ships for opening things; folders go to Nautilus,
        # which is what Mod+E opens too.
        "text/plain" = ["kitty-open.desktop"];
        "inode/directory" = ["org.gnome.Nautilus.desktop"];
        "x-scheme-handler/file" = ["org.gnome.Nautilus.desktop"];
        "x-scheme-handler/tg" = ["org.telegram.desktop.desktop"];
        # Nothing is mapped for image/* or x-scheme-handler/spotify: GIMP and
        # Spotify are not installed, and a default pointing at a missing
        # application produces an empty chooser instead of falling through to
        # the applications that do register for the type.
      };
    };

    # ── polkit ────────────────────────────────────────────────────────────────
    # Nix store binaries cannot carry setuid bits, so pkexec from polkit is
    # not executable as root out of the store. security.wrappers handles
    # this the standard way (built into the polkit module itself).
    security.polkit = {
      enable = true;
      enablePkexecWrapper = true;
    };
    services.udisks2.enable = true;

    # ── hardware ──────────────────────────────────────────────────────────────
    hardware = {
      # enableAllFirmware pulls the full 770 MB linux-firmware tree. This host is
      # AMD-only (services.xserver.videoDrivers = ["amdgpu"]), and
      # enableRedistributableFirmware — already true — covers it.
      enableRedistributableFirmware = true;
      bluetooth.enable = true;
      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
  };
}
