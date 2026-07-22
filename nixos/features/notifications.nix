{self, ...}: {
  flake.nixosModules.notifications = {pkgs, config, ...}: {
    environment.sessionVariables.QML2_IMPORT_PATH = "${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";

    environment.systemPackages = with pkgs; [
      quickshell
      swayosd
      libnotify
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-libav
    ];

    persistence.data.directories = [
      ".cache/quickshell"
    ];
  };
}
