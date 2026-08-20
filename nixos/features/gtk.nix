{self, ...}: {
  flake.nixosModules.gtk = {
    pkgs,
    lib,
    config,
    ...
  }: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
    theme-package = selfpkgs.skeuos-gtk;
    theme-name = "Skeuos-Grey-Dark";

    icon-theme-package = pkgs.colloid-icon-theme;
    icon-theme-name = "Colloid-Dark";

    cursor-theme-package = pkgs.bibata-cursors;
    cursor-theme-name = "Bibata-Modern-Classic";

    gtksettings = ''
      [Settings]
      gtk-theme-name = ${theme-name}
      gtk-icon-theme-name = ${icon-theme-name}
      gtk-cursor-theme-name = ${cursor-theme-name}
    '';
  in {
    environment = {
      etc = {
        "xdg/gtk-3.0/settings.ini".text = gtksettings;
        "xdg/gtk-4.0/settings.ini".text = gtksettings;
      };
    };

    environment.variables = {
      XCURSOR_THEME = cursor-theme-name;
      XCURSOR_SIZE = "24";
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
                    gtk-theme = theme-name;
                    icon-theme = icon-theme-name;
                    cursor-theme = cursor-theme-name;
                    color-scheme = "prefer-dark";
                  };
                };
              }
            ];
          };
        };
      };
    };

    environment.systemPackages = [
      theme-package
      icon-theme-package
      cursor-theme-package

      pkgs.gtk3
      pkgs.gtk4
      pkgs.adwaita-icon-theme
      pkgs.gnome-themes-extra
    ];

    systemd.user.tmpfiles.rules = [
      "L+ %h/.local/share/themes/${theme-name} - - - - ${theme-package}/share/themes/${theme-name}"
      "L+ %h/.local/share/icons/${icon-theme-name} - - - - ${icon-theme-package}/share/icons/${icon-theme-name}"
    ];

    services.flatpak.overrides = lib.mkIf config.services.flatpak.enable {
      global.Context.filesystems = ["xdg-data/icons:ro"];
    };
  };
}
