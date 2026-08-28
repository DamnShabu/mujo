{self, ...}: {
  flake.nixosModules.gtk = {
    pkgs,
    lib,
    config,
    ...
  }: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
    themePackage = selfpkgs.skeuos-gtk;
    themeName = "Skeuos-Grey-Dark";

    iconThemePackage = pkgs.colloid-icon-theme;
    iconThemeName = "Colloid-Dark";

    cursorThemePackage = pkgs.bibata-cursors;
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

    services.flatpak.overrides = lib.mkIf config.services.flatpak.enable {
      global.Context.filesystems = ["xdg-data/icons:ro"];
    };
  };
}
