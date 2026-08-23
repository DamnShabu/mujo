{self, ...}: {
  flake.nixosModules.notifications = {pkgs, config, ...}: {
    environment.sessionVariables.QML2_IMPORT_PATH = "${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";

    environment.systemPackages = with pkgs; [
      quickshell
      swayosd
      libnotify
    ];

    persistence.data.directories = [
      ".cache/quickshell"
      # Notification-center history (WP-04) survives the impermanence wipe.
      ".local/state/qsshell"
    ];
  };
}
