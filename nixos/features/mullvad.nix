{inputs, ...}: {
  flake.nixosModules.nix = {pkgs, lib, ...}: {
    imports = [];
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
        mullvad
    ];
    services.mullvad-vpn.enable = true;
  };
}
