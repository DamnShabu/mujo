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
          # No --max-old-space-size here: a 384 MB V8 old-space cap made the renderer
          # sit in back-to-back full GCs once a busy session filled the heap --
          # ~70% of a core burned continuously, window unresponsive after a few
          # minutes. This host has 62 GB of RAM; let V8 pick its own limit.
          VESKTOP_FLAGS = "--ozone-platform=wayland --enable-features=UseOzonePlatform,WaylandWindowDecorations --disable-features=SpareRendererForSitePerProcess,AudioServiceSandbox";
        };
      };
    };

    persistence.data.directories = [
      ".var/app/dev.vencord.Vesktop"
    ];
  };
}
