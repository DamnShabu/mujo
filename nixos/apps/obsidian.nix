{
  flake.nixosModules.obsidian = {
    lib,
    config,
    ...
  }: {
    services.flatpak.packages = ["md.obsidian.Obsidian"];

    # Expose the host git (and its config/libs) to the Obsidian Git plugin.
    # Point the plugin's "Git path" setting at /usr/bin/git.
    services.flatpak.overrides = lib.mkIf config.services.flatpak.enable {
      "md.obsidian.Obsidian".Context.filesystems = [
        "host-os:ro"
        "host-etc:ro"
      ];
    };

    persistence.data.directories = [
      ".var/app/md.obsidian.Obsidian"
    ];
  };
}
