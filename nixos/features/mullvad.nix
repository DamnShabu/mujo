{inputs, ...}: {
  flake.nixosModules.mullvad = {pkgs, lib, ...}: {
    imports = [];
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
        mullvad
    ];
    services.mullvad-vpn.enable = true;
  };
}
