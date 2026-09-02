{...}: {
  flake.nixosModules.security-network = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.security.mujo;
  in {
    config = lib.mkIf (cfg.enable && cfg.network.enable) {
      networking.firewall = {
        enable = lib.mkDefault true;
        allowPing = lib.mkDefault false;
        logRefusedConnections = lib.mkDefault true;
      };

      boot.kernel.sysctl = {
        # Reverse Path Filtering: reject packets whose source address is not reachable via the interface they arrived on (anti-spoofing)
        "net.ipv4.conf.all.rp_filter" = 1;
        "net.ipv4.conf.default.rp_filter" = 1;

        # Ignore ICMP redirects to prevent routing table tampering
        "net.ipv4.conf.all.accept_redirects" = 0;
        "net.ipv4.conf.default.accept_redirects" = 0;
        "net.ipv6.conf.all.accept_redirects" = 0;
        "net.ipv6.conf.default.accept_redirects" = 0;

        # Do not send ICMP redirects
        "net.ipv4.conf.all.send_redirects" = 0;
        "net.ipv4.conf.default.send_redirects" = 0;

        # Reject IP source routed packets
        "net.ipv4.conf.all.accept_source_route" = 0;
        "net.ipv4.conf.default.accept_source_route" = 0;
        "net.ipv6.conf.all.accept_source_route" = 0;
        "net.ipv6.conf.default.accept_source_route" = 0;

        # Log martian packets (impossible IP addresses)
        "net.ipv4.conf.all.log_martians" = 1;
        "net.ipv4.conf.default.log_martians" = 1;

        # Enable SYN cookies against SYN flood denial of service
        "net.ipv4.tcp_syncookies" = 1;

        # Protect against TIME-WAIT assassination (RFC 1337)
        "net.ipv4.tcp_rfc1337" = 1;

        # Ignore bogus ICMP error responses
        "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
        "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
      };
    };
  };
}
