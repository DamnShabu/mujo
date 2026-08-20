{self, inputs, ...}: {
  flake.nixosModules.gaming = {
    pkgs,
    lib,
    ...
  }: {
    hardware.graphics.enable = lib.mkDefault true;

    programs = {
      gamescope.enable = true;
    };

    environment.systemPackages = with pkgs; [
      dxvk
      gamescope
      mangohud
    ];

    services.zerotierone.enable = true;

    persistence.cache.directories = [
      "Games"
    ];

    nix.settings = {
      substituters = ["https://nix-gaming.cachix.org"];
      trusted-public-keys = ["nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="];
    };
  };
}
