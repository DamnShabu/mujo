{self, ...}: {
  flake.nixosModules.helium = {pkgs, ...}: {
    environment.systemPackages = [
      (self.packages."${pkgs.stdenv.hostPlatform.system}".helium)
    ];

    persistence.data.directories = [
      ".config/net.imput.helium"
      ".config/helium"
    ];

    persistence.cache.directories = [
      ".cache/net.imput.helium"
      ".cache/helium"
    ];
  };
}
