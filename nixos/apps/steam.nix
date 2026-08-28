{
  flake.nixosModules.steam = {...}: {
    services.flatpak.packages = ["com.valvesoftware.Steam"];

    hardware.steam-hardware.enable = true;
  };
}
