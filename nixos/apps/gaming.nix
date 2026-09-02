{...}: {
  flake.nixosModules.gaming = {pkgs, ...}: {
    programs = {
      gamescope.enable = true;
    };

    environment.systemPackages = with pkgs; [
      dxvk
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
