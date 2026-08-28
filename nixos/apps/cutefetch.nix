{self, ...}: {
  flake.nixosModules.cutefetch = {pkgs, ...}: {
    environment.systemPackages = [
      (self.packages."${pkgs.stdenv.hostPlatform.system}".cutefetch)
    ];
  };
}
