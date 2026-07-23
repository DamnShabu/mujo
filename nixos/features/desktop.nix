{inputs, self, ...}: {
  flake.nixosModules.desktop = {pkgs, config, lib, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [
      self.nixosModules.gtk
      self.nixosModules.vicinae
      self.nixosModules.pipewire
      self.nixosModules.zen
    ];

    # ── niri Wayland compositor ───────────────────────────────────────────────
    # This wires:
    #   - niri into services.displayManager.sessionPackages (so the greeter can
    #     discover and launch it),
    #   - xdg-desktop-portal + recommended portals,
    #   - services.graphical-desktop.enable → graphical-session.target in the
    #     user systemd instance (so user services can declare their dependencies).
    programs.niri.enable = true;

    # ── display manager : greetd + tuigreet ────────────────────────────────────
    # tuigreet is the greeter. It discovers sessions from the directories below,
    # which NixOS populates from services.displayManager.sessionPackages.
    # The niri desktop entry there points to niri-session(1), which in turn
    # imports environment, starts niri.service in the user systemd instance,
    # and waits for it to terminate.
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --sessions /run/current-system/sw/share/wayland-sessions --sessions /run/current-system/sw/share/xsessions --no-run-all";
          user = "greeter";
        };
      };
    };

    services.displayManager.enable = true;

    # ── GUI session environment ────────────────────────────────────────────────
    environment.sessionVariables = {
      XCURSOR_THEME = "Bibata-Modern-Classic";
      XCURSOR_SIZE = "24";
      GDK_BACKEND = "wayland,x11";
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
    };

    # ── packages ──────────────────────────────────────────────────────────────
    environment.systemPackages = [
      selfpkgs.terminal
      pkgs.pcmanfm
      pkgs.wl-clipboard
      pkgs.xdg-utils
      pkgs.tuigreet
      pkgs.age
      pkgs.sops
      pkgs.bibata-cursors
    ];

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
    i18n.extraLocaleSettings = config.preferences.locale.extra;

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
        "inode/directory" = ["pcmanfm.desktop"];
        "x-scheme-handler/file" = ["pcmanfm.desktop"];
        "x-scheme-handler/tg" = ["org.telegram.desktop.desktop"];
        "x-scheme-handler/spotify" = ["spotify.desktop"];
      };
    };

    # ── polkit ────────────────────────────────────────────────────────────────
    security.polkit.enable = true;

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
