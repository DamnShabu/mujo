{
  flake.nixosModules.zen = {
    config,
    lib,
    ...
  }: {
    services.flatpak.packages = ["app.zen_browser.zen"];

    services.flatpak.overrides = lib.mkIf config.services.flatpak.enable {
      "app.zen_browser.zen".Context.filesystems = [
        "~/Downloads"
        "xdg-data/applications:ro"
        "xdg-data/mime:ro"
        "xdg-config/mimeapps.list:ro"
      ];
    };

    persistence.data.directories = [
      ".var/app/app.zen_browser.zen/.zen"
    ];

    persistence.cache.directories = [
      ".var/app/app.zen_browser.zen/cache"
    ];
  };
}
