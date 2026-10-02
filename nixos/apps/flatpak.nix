{
  flake.nixosModules.flatpak = {...}: {
    services.flatpak = {
      remotes = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];

      # Everything installed from Flathub on the host, so a fresh install comes
      # back with the same applications (several are bound to niri keys:
      # feishin Mod+M, VS Code Mod+T, Super Productivity Mod+P). Apps with
      # their own module (Steam, Zen, Vesktop, Obsidian, Telegram, Cordial) are
      # declared there. io.yoyogames.GameMakerBeta is not here: it came from a
      # local .flatpak bundle, which has no URL to install from.
      packages = [
        "com.axosoft.GitKraken"
        "com.brave.Browser"
        "com.github.libresprite.LibreSprite"
        "com.github.tchx84.Flatseal"
        "com.super_productivity.SuperProductivity"
        "com.usebottles.bottles"
        "com.visualstudio.code"
        "de.haeckerfelix.Fragments"
        "dev.zed.Zed"
        "io.github.flattool.Warehouse"
        "io.github.kolunmi.Bazaar"
        "io.gitlab.ilshat_apps.gitpulsar"
        "it.mijorus.gearlever"
        "net.blockbench.Blockbench"
        "org.desktop_plus.desktop-plus"
        "org.filezillaproject.Filezilla"
        "org.gnome.font-viewer"
        "org.jeffvli.feishin"
        "org.kde.ark"
        "org.libreoffice.LibreOffice"
        "org.prismlauncher.PrismLauncher"
        "org.qbittorrent.qBittorrent"
        "org.videolan.VLC"
      ];

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
