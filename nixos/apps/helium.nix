{self, ...}: {
  flake.nixosModules.helium = {pkgs, ...}: {
    environment.systemPackages = [
      (self.packages."${pkgs.stdenv.hostPlatform.system}".helium)
    ];

    persistence.data.directories = [
      ".config/helium"
    ];

    persistence.cache.directories = [
      ".cache/helium"
    ];
  };
}
