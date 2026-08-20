{
  flake.nixosModules.flatpak = {...}: {
    services.flatpak = {
      remotes = [{
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }];

      packages = ["com.github.tchx84.Flatseal"];

      overrides = {
        global.Context = {
          sockets = ["wayland" "x11"];
          talk-names = [
            "org.kde.klipper"
            "org.freedesktop.portal.Desktop"
            "org.freedesktop.portal.*"
          ];
        };
      };
    };

    persistence.directories = [
      "/var/lib/flatpak"
    ];
  };
}
