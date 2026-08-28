{self, ...}: {
  flake.nixosModules.preload = {
    lib,
    config,
    ...
  }: let
    cfg = config.services.preload;
  in {
    imports = [
      # nixpkgs' rename.nix declares services.preload as a *removed* option
      # (mkRemovedOptionModule, added 2025-11-29 when the package was dropped).
      # That typeless leaf declaration + its throw-apply conflict with the
      # nested options below, and the removed-module assertion fires whenever
      # the option is defined. Since preload is vendored back (see
      # modules/perSystem.nix), the removal entry must go; this disables the
      # whole rename module, which is only consulted for option renames the
      # host does not use.
      {disabledModules = ["rename.nix"];}
      # rename.nix also declares the environment.checkConfigurationOptions
      # alias (mkAliasOptionModule ["environment" "checkConfigurationOptions"]
      # ["_module" "check"]); disabling the module removes that declaration
      # too, and some part of the toplevel build evaluation still reads it.
      # Re-declare it with the same shape the alias would have given it.
      {
        options.environment.checkConfigurationOptions = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to check the configuration options.";
        };
        config.environment.checkConfigurationOptions = lib.mkDefault config._module.check;
      }
    ];

    options.services.preload = {
      enable = lib.mkEnableOption "adaptive readahead daemon (preload)";

      # Vendored: preload was removed from nixpkgs, so it is built from
      # modules/perSystem.nix (packages.preload).
      package = lib.mkOption {
        type = lib.types.package;
        description = "The preload package to use";
      };

      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/preload";
        description = "Directory for the preload state file (preload.state)";
      };
    };

    config = lib.mkIf cfg.enable {
      # A conffile is mandatory: preloadd's default conffile is
      # $out/etc/preload.conf from the package, which ships FHS prefixes ending
      # in `!/` (reject-anything-else) that exclude /nix/store, /run and /home.
      # Ship a NixOS-tuned one at /etc/preload.conf instead (tmpfs /etc is fine:
      # environment.etc regenerates the symlink every boot) and point the daemon
      # at it explicitly.
      environment.etc."preload.conf".text = ''
        [model]

        # cycle:
        #
        # Quantum of time for preload.  Preload performs data gathering and
        # predictions every cycle.
        #
        # unit: seconds
        # default: 20
        cycle = 20

        # usecorrelation:
        #
        # Whether correlation coefficient should be used in the prediction
        # algorithm.
        #
        # default: true
        usecorrelation = true

        # minsize:
        #
        # Minimum sum of the length of maps of the process for preload to
        # consider tracking the application.
        #
        # unit: bytes
        # default: 2000000
        minsize = 2000000

        # The following control how much memory preload is allowed to use for
        # preloading in each cycle.  All values are percentages and are clamped
        # to -100 to 100.  The total memory preload uses for prefetching is
        # then computed using the formula:
        #
        #   max (0, TOTAL * memtotal + FREE * memfree) + CACHED * memcached
        #
        # where TOTAL, FREE, and CACHED are read at runtime from /proc/meminfo.
        memtotal = -10
        memfree = 50
        memcached = 0

        [system]

        doscan = true
        dopredict = true

        # autosave:
        #
        # Preload will automatically save the state to disk every autosave
        # period.  Turning off autosave completely is not advised.
        #
        # unit: seconds
        # default: 3600
        autosave = 3600

        # Prefix lists: accept on first match, reject on first `!`-prefixed
        # match, accept by default if nothing matches.  This host is NVMe with
        # tmpfs / and /home (impermanence) and system-wide flatpak, so:
        # - /nix/store, /run/current-system and /var/lib/flatpak hold everything
        #   real that is ever executed or mapped;
        # - /var/cache is worth prefetching;
        # - /home, /run/user, /dev, /proc, /sys, /tmp are tmpfs/pseudo-fs and
        #   would only waste RAM if tracked.  The trailing `!/` rejects the rest.
        mapprefix = /nix/store/;/run/current-system/;/var/lib/flatpak/;/var/cache/;!/
        exeprefix = /nix/store/;/run/current-system/;/var/lib/flatpak/;!/

        # maxprocs:
        #
        # Maximum number of processes to use to do parallel readahead.
        #
        # default: 30
        processes = 30

        # sortstrategy:
        #
        # 0 -- SORT_NONE:  No I/O sorting.  Useful on flash memory.
        # 1 -- SORT_PATH:  Sort based on file path only.
        # 2 -- SORT_INODE: Sort based on inode number.
        # 3 -- SORT_BLOCK: Sort I/O based on disk block (HDD-oriented).
        #
        # default: 3
        sortstrategy = 0
      '';

      systemd.services.preload = {
        description = "Adaptive readahead daemon (preload)";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "simple";
          # -c /etc/preload.conf points at the NixOS-tuned conffile above (the
          # package default would load the FHS conf that excludes the store).
          # -l '' logs to stderr (i.e. the journal); --foreground keeps the
          # daemon from double-forking away from systemd.
          ExecStart = "${cfg.package}/bin/preloadd -c /etc/preload.conf -l '' --foreground";
          Restart = "always";
          RestartSec = 2;
          # preload learns from atime, so ProtectHome is deliberately NOT set
          # (hiding /home would break learning for user apps). The rest is
          # sandboxing that the daemon tolerates: it only reads files, forks
          # readahead helpers (AF_UNIX socketpair), and writes its state file
          # under ReadWritePaths.
          PrivateTmp = true;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          ReadWritePaths = cfg.stateDir;
          # Only preload data during CPU idle time (as upstream's init script
          # does via IONICE_OPTS="-c3").
          IOSchedulingClass = 3;
        };
      };

      # State survives the tmpfs root via impermanence (pattern as in
      # nixos/features/mullvad.nix, persisted under /persist/system).
      persistence.directories = [
        {directory = cfg.stateDir;}
      ];
    };
  };
}
