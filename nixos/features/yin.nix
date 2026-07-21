{self, ...}: {
  flake.nixosModules.yin = {config, ...}: {
    persistence.cache.directories = [
      ".cache/yin"
    ];
  };
}
