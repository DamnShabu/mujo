{self, ...}: {
  flake.nixosModules.quickshell = {pkgs, config, ...}: let
    qs = import ../../quickshell/_default.nix {inherit self pkgs;};
    qmlDeps = with pkgs.qt6; [qtmultimedia qtdeclarative qtwayland qt5compat];
    qmlPath = pkgs.lib.makeSearchPath "lib/qt-6/qml" qmlDeps;
    mkDaemon = {
      command,
      path ? [],
      environment ? {},
    }: {
      # Quickshell is a Wayland shell client; wait for niri.service in the
      # user systemd instance so the compositor is ready before quickshell
      # tries to connect (avoids silent crash on early boot).
      after = ["niri.service"];
      serviceConfig = {
        ExecStart = command;
        Restart = "always";
        RestartSec = 2;
      };
      environment = {QML2_IMPORT_PATH = qmlPath;} // environment;
      inherit path;
      wantedBy = ["graphical-session.target"];
      restartTriggers = ["/run/current-system"];
    };
    daemons = ["qs-combined" "swayosd" "vicinae"];
    user = "yurii";
    uid = toString config.users.users.${user}.uid;
  in {
    environment.systemPackages = [qs.mujo];

    services.udev.extraRules = ''
      KERNEL=="event*", SUBSYSTEM=="input", MODE="0666"
    '';

    systemd.user.services = {
      qs-combined = mkDaemon {
        command = "${pkgs.quickshell}/bin/quickshell -p ${qs.combined}/Shell.qml";
        path = [self.packages.${pkgs.stdenv.hostPlatform.system}.cursor-tracker];
        environment = {
          QS_ICON_THEME = "Gruvbox Plus Dark";
          XDG_DATA_DIRS = "/run/current-system/sw/share";
        };
      };
      swayosd = mkDaemon {command = "${pkgs.swayosd}/bin/swayosd-server --style ${qs.swayosdCSS}";};
      vicinae = mkDaemon {
        command = "${pkgs.vicinae}/bin/vicinae server --replace";
        path = [pkgs.flatpak pkgs.mullvad-vpn];
        environment.XDG_DATA_DIRS = pkgs.lib.concatStringsSep ":" [
          "/run/current-system/sw/share"
          "/var/lib/flatpak/exports/share"
          "/home/${user}/.local/share/flatpak/exports/share"
        ];
      };
    };
    system.activationScripts.quickshell = pkgs.lib.mkAfter ''
      if [ -d /run/user/${uid} ] && \
         systemctl --machine=${user}@ --user is-active graphical-session.target >/dev/null 2>&1; then
        systemctl --machine=${user}@ --user daemon-reload 2>/dev/null || true
        ${pkgs.lib.concatMapStringsSep "\n" (svc: ''
          systemctl --machine=${user}@ --user restart ${svc}.service 2>/dev/null || true
        '') daemons}
      fi
    '';
  };
}
