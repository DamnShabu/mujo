{self, ...}: {
  flake.nixosModules.notifications = {
    pkgs,
    config,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      quickshell
      libnotify
    ];

    persistence.data.directories = [
      # Notification-center history (WP-04) survives the impermanence wipe.
      ".local/state/qsshell"
    ];

    persistence.cache.directories = [
      ".cache/quickshell"
    ];
  };
}
