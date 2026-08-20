{ lib, ... }: {
  networking = {
    hostName = lib.mkDefault "main";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [11434];
    };
  };
}
