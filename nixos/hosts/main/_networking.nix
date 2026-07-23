{ lib, ... }: {
  networking = {
    hostName = lib.mkDefault "main";
    networkmanager.enable = true;
    firewall.enable = true;
  };
}
