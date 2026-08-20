{inputs, self, ...}: {
  flake.nixosModules.desktop = {pkgs, config, lib, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [
      self.nixosModules.gtk
      self.nixosModules.vicinae
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

    systemd.services.display-manager.environment.QML_IMPORT_PATH = "${pkgs.qt6.qt5compat}/lib/qt-6/qml";

    services.displayManager.enable = true;

    # ── GUI session environment ────────────────────────────────────────────────
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland;xcb";

      XDG_CURRENT_DESKTOP = "niri:GNOME";
    };

    # ── packages ──────────────────────────────────────────────────────────────
    environment.systemPackages = [
      selfpkgs.terminal
      pkgs.wl-clipboard
      pkgs.xdg-utils
      pkgs.gparted
      pkgs.nautilus
    ];

    services.gvfs.enable = true;

    # ── fonts ─────────────────────────────────────────────────────────────────
    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      ubuntu-sans
      cm_unicode
      corefonts
      unifont
    ];

    fonts.fontconfig.defaultFonts = {
      serif = ["Ubuntu Sans"];
      sansSerif = ["Ubuntu Sans"];
      monospace = ["JetBrainsMono Nerd Font"];
    };

    # ── locale ────────────────────────────────────────────────────────────────
    time.timeZone = config.preferences.locale.timeZone;
    i18n.defaultLocale = config.preferences.locale.default;

    # ── desktop file associations (XDG) ───────────────────────────────────────
    xdg.mime = {
      enable = true;
      defaultApplications = {
        "text/html" = ["app.zen_browser.zen.desktop"];
        "x-scheme-handler/http" = ["app.zen_browser.zen.desktop"];
        "x-scheme-handler/https" = ["app.zen_browser.zen.desktop"];
        "application/pdf" = ["app.zen_browser.zen.desktop"];
        "image/png" = ["org.gimp.GIMP.desktop"];
        "image/jpeg" = ["org.gimp.GIMP.desktop"];
        "image/gif" = ["org.gimp.GIMP.desktop"];
        "image/webp" = ["org.gimp.GIMP.desktop"];
        "image/bmp" = ["org.gimp.GIMP.desktop"];
        "image/svg+xml" = ["org.gimp.GIMP.desktop"];
        "text/markdown" = ["md.obsidian.Obsidian.desktop"];
        "text/plain" = ["org.gnome.TextEditor.desktop" "kitty.desktop"];
        "inode/directory" = ["kitty.desktop"];
        "x-scheme-handler/file" = ["kitty.desktop"];
        "x-scheme-handler/tg" = ["org.telegram.desktop.desktop"];
        "x-scheme-handler/spotify" = ["spotify.desktop"];
      };
    };

    # ── polkit ────────────────────────────────────────────────────────────────
    security.polkit.enable = true;
    # ponytail: Nix store binaries cannot carry setuid bits, so pkexec from
    # polkit is not executable as root out of the store. Create a setuid-root
    # wrapper in /run at boot via a systemd oneshot.
    systemd.services.pkexec-wrapper = {
      description = "Create setuid pkexec wrapper";
      wantedBy = [ "sysinit.target" ];
      before = [ "polkit.service" ];
      after = [ "suid-sgid-wrappers.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p /run/wrappers/bin && cp ${pkgs.polkit}/bin/pkexec /run/wrappers/bin/pkexec && chmod 4755 /run/wrappers/bin/pkexec'";
      };
    };
    services.udisks2.enable = true;

    # ── hardware ──────────────────────────────────────────────────────────────
    hardware = {
      enableAllFirmware = true;
      bluetooth.enable = true;
      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
  };
}
