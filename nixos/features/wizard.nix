{self, ...}: {
  flake.nixosModules.wizard = {pkgs, config, lib, ...}: let
    qs = import ../../quickshell/_default.nix {inherit self pkgs;};
    user = config.preferences.user.name;
    uid = toString config.users.users.${user}.uid;
    wizardNeeded = !builtins.pathExists ../../user-config/_user.nix;

    qmlDeps = with pkgs.qt6; [qtmultimedia qtdeclarative qtwayland qt5compat] ++ [pkgs.quickshell];
    qmlPath = pkgs.lib.makeSearchPath "lib/qt-6/qml" qmlDeps;
  in {
    # Only activate when the wizard hasn't run yet
    config = lib.mkIf wizardNeeded {
      environment.systemPackages = [qs.wizard];

      systemd.user.services.setup-wizard = {
        description = "First-boot setup wizard";
        after = ["graphical-session.target"];
        wants = ["graphical-session.target"];
        wantedBy = ["graphical-session.target"];
        serviceConfig = {
          ExecStart = "${pkgs.quickshell}/bin/quickshell -p ${qs.wizard}/Wizard.qml";
          Restart = "no";
          Environment = "QML2_IMPORT_PATH=${qmlPath}";
        };
        environment = {
          QML2_IMPORT_PATH = qmlPath;
          XDG_DATA_DIRS = "/run/current-system/sw/share";
        };
        path = with pkgs; [bash coreutils openssl polkit niri];
        restartTriggers = [];
      };
    };
  };
}
