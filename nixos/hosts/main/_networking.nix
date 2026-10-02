{...}: {
  networking = {
    # hostName and firewall.enable come from nixos/core/system-preferences.nix
    # (the Settings app's JSON). A second mkDefault here made any change there
    # a "conflicting definition values" build failure.

    # Wired-only (eno1): networkd DHCP replaces NetworkManager. Explicit false
    # because the ambxst module sets networkmanager.enable via mkDefault.
    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = true;

    # The router advertises IPv6 but no traffic actually routes: every global
    # IPv6 address resolves fine and then times out on connect (~1s each).
    # glibc returns AAAA first, so clients that connect serially instead of
    # doing Happy Eyeballs (ureq, used by skwd-wall) burn ~3s per connection
    # before falling back to IPv4. That pushed skwd-wall-scan --remote-thumb
    # past skwd-walld's 10s budget, so wallpaper browser thumbnails were
    # killed mid-download and never rendered (13.0s -> 0.9s for 24 thumbs).
    #
    # RFC 3484 precedence table, glibc defaults except ::ffff:0:0/96, which is
    # raised above ::/0 so IPv4 sorts first. Setting this option replaces the
    # built-in table wholesale, hence the other rows.
    getaddrinfo.precedence = {
      "::1/128" = 50;
      "::/0" = 40;
      "2002::/16" = 30;
      "::/96" = 20;
      "::ffff:0:0/96" = 100;
    };
  };
}
