{inputs, ...}: {
  # mujō Roblox manager, now its own flake (inputs.roblox-manager): the app,
  # its Cordial fork and the AppImage live there. What stays here is specific
  # to this machine.
  flake.nixosModules.roblox-manager = {
    imports = [inputs.roblox-manager.nixosModules.default];

    # Mullvad's tracker blocklist (block_trackers, services/mullvad.nix)
    # NXDOMAINs Roblox's telemetry hosts, and the client does not survive it:
    # Sober, the runtime this used before Cordial and the same Android engine,
    # segfaulted in its HttpClient thread minutes into a session, right after
    # one of these lookups failed (the session log ended on "Could not resolve
    # host: ecsv2.roblox.com"). Mullvad only lets DNS reach its own filtered
    # resolver, so these names cannot be routed to an unfiltered one; pin them
    # instead. Every roblox.com host is a CNAME to titanium.roblox.com and the
    # edge picks by SNI, so any edge IP serves them. Cost: Roblox gets its
    # client telemetry again.
    # ponytail: static edge IP; if Roblox retires it these fail again -- refresh
    # with `getent hosts titanium.roblox.com`.
    networking.hosts."128.116.13.3" = [
      "ecsv2.roblox.com"
      "metrics.roblox.com"
      "tracing.roblox.com"
      "lms.roblox.com"
    ];

    # accounts.json: names, user ids, Cordial profile names -- no secrets.
    # Cordial's profiles hold each account's Roblox storage and settings; its
    # config dir holds shell.json, if you write one. Sessions are not in
    # either: they are in the keyring.
    persistence.data.directories = [
      ".local/share/rbxmgr"
      ".local/share/cordial"
      ".config/cordial"
    ];
    # The extracted Roblox build: regenerable (cordial-fetch), but ~200 MB and
    # a download when no copy is on the machine.
    persistence.cache.directories = [
      ".cache/cordial"
    ];
  };
}
