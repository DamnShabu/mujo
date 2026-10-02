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
      # No mkDefault: lists merge, and modules such as podman's define this at
      # normal priority, which silently discarded a mkDefault'd list -- ports
      # added in Settings were never opened.
      allowedTCPPorts = prefs.firewall.allowedTCPPorts or [];
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

    # Off by default: it hashes and hardlinks every path on the critical path
    # of every build, and nix.optimise.automatic (nixos/core/nix.nix) gets the
    # same disk saving on a schedule.
    nix.settings.auto-optimise-store = lib.mkDefault (prefs.autoOptimiseStore or false);

    zramSwap = {
      enable = lib.mkDefault (prefs.zramSwap.enable or true);
      memoryPercent = lib.mkDefault (prefs.zramSwap.memoryPercent or 50);
    };

    security.mujo = {
      boot.secureBoot = lib.mkDefault (prefs.security.secureBoot or false);
      storage = {
        encryptedSwap = lib.mkDefault (prefs.storage.encryptedSwap or true);
        coredumpDisabled = lib.mkDefault (prefs.security.coredumpDisabled or true);
      };
    };

    apps.trust = {
      launcherIntegration = lib.mkDefault (prefs.trust.launcherIntegration or false);
    };
  };
}
