{lib, ...}: let
  file = ./system-preferences.json;
  prefs =
    if builtins.pathExists file
    then builtins.fromJSON (builtins.readFile file)
    else {};
in {
  flake.nixosModules.system-preferences = {config, ...}: {
    networking.hostName = lib.mkDefault (prefs.hostname or "main");
    time.timeZone = lib.mkDefault (prefs.timezone or config.preferences.locale.timeZone);
    i18n.defaultLocale = lib.mkDefault (prefs.locale or config.preferences.locale.default);

    networking.firewall = {
      enable = lib.mkDefault (prefs.firewall.enable or true);
      allowedTCPPorts = lib.mkDefault (prefs.firewall.allowedTCPPorts or [11434]);
    };

    services.openssh = {
      enable = lib.mkDefault (prefs.ssh.enable or false);
      settings = {
        PermitRootLogin = lib.mkDefault "no";
        PasswordAuthentication = lib.mkDefault false;
        KbdInteractiveAuthentication = lib.mkDefault false;
        X11Forwarding = lib.mkDefault false;
      };
      openFirewall = lib.mkDefault true;
    };

    nix.settings.auto-optimise-store = lib.mkDefault (prefs.autoOptimiseStore or true);

    zramSwap = {
      enable = lib.mkDefault (prefs.zramSwap.enable or true);
      memoryPercent = lib.mkDefault (prefs.zramSwap.memoryPercent or 50);
    };
  };
}
