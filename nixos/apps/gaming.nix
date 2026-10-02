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
  };
}
