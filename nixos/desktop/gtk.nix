{self, ...}: {
  flake.nixosModules.gtk = {
    pkgs,
    lib,
    config,
    options,
    ...
  }: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
    themePackage = selfpkgs.skeuos-gtk;
    themeName = "Skeuos-Grey-Dark";

    iconThemePackage = pkgs.colloid-icon-theme;
    iconThemeName = "Colloid-Dark";

    # bibata-cursors ships all 12 colour/handedness variants (322 MB); only
    # cursorThemeName below is ever referenced. Slice out the one theme — same
    # trick modules/flake/perSystem.nix uses for skeuos-gtk.
    cursorThemePackage = pkgs.runCommand "bibata-modern-classic" {} ''
      mkdir -p $out/share/icons
      cp -a ${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Classic $out/share/icons/
    '';
    cursorThemeName = "Bibata-Modern-Classic";

    gtksettings = ''
      [Settings]
      gtk-theme-name = ${themeName}
      gtk-icon-theme-name = ${iconThemeName}
      gtk-cursor-theme-name = ${cursorThemeName}
      gtk-xft-antialias = 1
      gtk-xft-hinting = 1
      gtk-xft-hintstyle = hintslight
      gtk-xft-rgba = rgb
    '';
  in {
    environment = {
      etc = {
        "xdg/gtk-3.0/settings.ini".text = gtksettings;
        "xdg/gtk-4.0/settings.ini".text = gtksettings;
      };
    };

    environment.variables = {
      XCURSOR_THEME = cursorThemeName;
      XCURSOR_SIZE = "24";
      # Quickshell resolves freedesktop icon names against this theme. The qs-bar
      # service sets it too (its env is built explicitly, since the user manager
      # environment can be truncated on early boot); this is what makes an
      # interactive `qs -p` and a terminal-launched `mujo settings` render the
      # same icons as the running shell.
      QS_ICON_THEME = iconThemeName;
    };

    programs = {
      dconf = {
        enable = lib.mkDefault true;
        profiles = {
          user = {
            databases = [
              {
                lockAll = false;
                settings = {
                  "org/gnome/desktop/interface" = {
                    gtk-theme = themeName;
                    icon-theme = iconThemeName;
                    cursor-theme = cursorThemeName;
                    color-scheme = "prefer-dark";
                    font-antialiasing = "rgba";
                    font-hinting = "slight";
                    font-rgba-order = "rgb";
                  };
                };
              }
            ];
          };
        };
      };
    };

    environment.systemPackages = [
      themePackage
      iconThemePackage
      cursorThemePackage

      pkgs.gtk3
      pkgs.gtk4
      pkgs.adwaita-icon-theme
      pkgs.gnome-themes-extra
    ];

    systemd.user.tmpfiles.rules = [
      "L+ %h/.local/share/themes/${themeName} - - - - ${themePackage}/share/themes/${themeName}"
      "L+ %h/.local/share/icons/${iconThemeName} - - - - ${iconThemePackage}/share/icons/${iconThemeName}"
    ];

    services = lib.optionalAttrs (options.services ? flatpak && options.services.flatpak ? overrides) {
      flatpak.overrides = lib.mkIf (config.services.flatpak.enable or false) {
        global.Context.filesystems = ["xdg-data/icons:ro" "xdg-data/themes:ro"];
      };
    };
  };
}
