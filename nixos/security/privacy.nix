{...}: {
  flake.nixosModules.security-privacy = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.security.mujo;
  in {
    options.security.mujo.privacy.dnsOverTls = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Force DNS-over-TLS through systemd-resolved.

        Off by default because the Mullvad daemon manages DNS while a tunnel is
        up (see `nixos/services/mullvad.nix`, which turns on its ad, tracker and
        malware blocking). Forcing resolved to a different upstream fights it
        and can leave the machine with no working resolver when the tunnel
        state changes. Turn this on only if Mullvad is not in use.
      '';
    };

    config = lib.mkIf (cfg.enable && cfg.privacy.enable) {
      # ── network-layer identifiers ───────────────────────────────────────
      #
      # The goal from docs/privacy-model.md is minimising unique entropy, not
      # spoofing. "stable" derives a per-network MAC from a host secret: the
      # factory address never goes out on the wire, and a given network still
      # sees a consistent device, so DHCP reservations and captive portals keep
      # working. "random" would re-roll on every connect and make the machine
      # more conspicuous, not less.
      networking.networkmanager = {
        wifi.macAddress = lib.mkDefault "stable-ssid";
        wifi.scanRandMacAddress = lib.mkDefault true;
        ethernet.macAddress = lib.mkDefault "stable";

        connectionConfig = {
          # The hostname is a stable, often personal identifier ("yurii-laptop")
          # handed to every DHCP server the machine ever meets, and it is not
          # needed to get a lease.
          "ipv4.dhcp-send-hostname" = false;
          "ipv6.dhcp-send-hostname" = false;
        };
      };

      # NetworkManager's connectivity check fetches a URL after every network
      # change, which announces the machine to a third party on each new
      # network. The desktop only uses it to draw a "limited connectivity" icon.
      environment.etc."NetworkManager/conf.d/20-mujo-no-connectivity-check.conf".text = ''
        [connectivity]
        enabled=false
      '';

      # ── name resolution ─────────────────────────────────────────────────
      #
      # LLMNR and mDNS broadcast the hostname, and answer queries about it, to
      # every device on whatever network the machine joins. That is a standing
      # announcement on cafe and hotel wifi for a feature this host does not use.
      services.resolved = {
        settings.Resolve =
          {
            LLMNR = "no";
            MulticastDNS = "no";
          }
          // lib.optionalAttrs cfg.privacy.dnsOverTls {
            DNSOverTLS = "yes";
          };
      };

      # ── IPv6 addressing ─────────────────────────────────────────────────
      #
      # IPv6 privacy extensions (RFC 4941) come from the NixOS option, not from
      # a raw sysctl. nixos/modules/tasks/network-interfaces.nix already defines
      # net.ipv6.conf.*.use_tempaddr from networking.tempAddresses, so setting
      # the sysctl directly collided with it and made the entire host
      # configuration fail to evaluate. "default" is the value that both
      # generates temporary addresses and prefers them as source addresses.
      networking.tempAddresses = lib.mkDefault "default";

      boot.kernel.sysctl = {
        # RFC 7217: derive stable-but-per-prefix IPv6 interface identifiers
        # rather than embedding the NIC's MAC address in every packet. nixpkgs
        # does not set this one, so it does not conflict.
        "net.ipv6.conf.all.addr_gen_mode" = 2;
        "net.ipv6.conf.default.addr_gen_mode" = 2;
      };
    };
  };
}
