{
  flake.nixosModules.discord = {
    lib,
    config,
    ...
  }: {
    services.flatpak.packages = ["dev.vencord.Vesktop"];

    services.flatpak.overrides = lib.mkIf config.services.flatpak.enable {
      "dev.vencord.Vesktop" = {
        Context.sockets = ["wayland" "!x11" "!fallback-x11"];
        Environment = {
          NODE_OPTIONS = "--max-old-space-size=384";
          VESKTOP_FLAGS = "--ozone-platform=wayland --enable-features=UseOzonePlatform,WaylandWindowDecorations --disable-features=SpareRendererForSitePerProcess,AudioServiceSandbox --js-flags=--max-old-space-size=384 --optimize_for_size";
        };
      };
    };

    persistence.data.directories = [
      ".var/app/dev.vencord.Vesktop"
    ];
  };
}
