{self, ...}: {
  flake.nixosModules.vicinae = {
    pkgs,
    config,
    lib,
    ...
  }: let
    vicinaePkg = self.packages.${pkgs.stdenv.hostPlatform.system}.vicinae;
    generationTrigger = self.rev or self.dirtyRev or "unknown";
    user = config.preferences.user.name;

    appDataDirs = pkgs.lib.concatStringsSep ":" [
      "/run/current-system/sw/share"
      "/etc/profiles/per-user/${user}/share"
      "/home/${user}/.nix-profile/share"
      "/var/lib/flatpak/exports/share"
      "/home/${user}/.local/share/flatpak/exports/share"
    ];
  in {
    environment.systemPackages = [vicinaePkg];

    persistence.data.directories = [
      ".config/vicinae"
      ".local/share/vicinae"
    ];

    systemd.user.services.vicinae = {
      description = "Vicinae Launcher Daemon";
      after = ["niri.service" "graphical-session.target"];
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      path = with pkgs; [
        "/run/wrappers"
        "/etc/profiles/per-user/${user}"
        bash
        coreutils
        pulseaudio
        xdg-utils
        "/run/current-system/sw"
      ];
      environment = {
        XDG_DATA_DIRS = appDataDirs;
      };
      serviceConfig = {
        ExecStart = "${vicinaePkg}/bin/vicinae server --replace";
        Restart = "always";
        RestartSec = 2;
      };
      restartTriggers = [generationTrigger];
    };

    systemd.user.targets.graphical-session.upholds = ["vicinae.service"];
  };
}
