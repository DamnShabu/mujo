{...}: {
  # The registry's state machine, checked offline by `nix flake check`: the
  # same writer and jq library the host installs, against a scratch registry.
  perSystem = {pkgs, ...}: {
    checks.trustRegistry =
      pkgs.runCommand "trust-registry-check" {
        nativeBuildInputs = with pkgs; [bash coreutils findutils jq util-linux];
      } ''
        cp ${./mujo-trust.jq} mujo-trust.jq
        cp ${./mujo-trust-registry.sh} mujo-trust-registry.sh
        cp ${./test-mujo-trust-registry.sh} test-mujo-trust-registry.sh
        bash test-mujo-trust-registry.sh
        touch $out
      '';

    # Application launch resolution against a fake Flatpak tree and PATH.
    checks.trustLaunch =
      pkgs.runCommand "trust-launch-check" {
        nativeBuildInputs = with pkgs; [bash coreutils jq];
      } ''
        cp ${./mujo-trust-launch.sh} mujo-trust-launch.sh
        cp ${./test-mujo-trust-launch.sh} test-mujo-trust-launch.sh
        bash test-mujo-trust-launch.sh
        touch $out
      '';
  };

  flake.nixosModules.app-trust = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.apps.trust;

    dbDir = "/var/lib/mujo-trust";
    dbFile = "${dbDir}/registry.json";
    sockPath = "/run/mujo/trust.sock";
    # Root-only; nixos/security/broker.nix reports violations here.
    reportSockPath = "/run/mujo/trust-report.sock";

    # Subtractive `flatpak run` overrides for a GRADUATED Flatpak. §7 of
    # docs/application-trust.md calls capability profiles "enforced, not
    # advisory"; bwrap enforces them for a native application, but a Flatpak
    # brings its own sandbox and the engine used to launch it with exactly what
    # its manifest asked for -- so for Flatpaks the profile was advice. These
    # flags can only *remove* what the manifest granted, which is the missing
    # enforcement and nothing more.
    #
    # Each was measured against this machine's graduated Flatpaks before being
    # picked, not chosen from the manual:
    #
    #   * `devices=all` -- declared by Zen and Vesktop -- hands the application
    #     the host's entire /dev: /dev/input/event* (readable through the
    #     user's `input` group, so a working keylogger), /dev/nvme0n1, /dev/mem,
    #     /dev/tpm0, /dev/kvm, /dev/uinput. `--nodevice=all --device=dri` takes
    #     that from ~190 entries to 18 and keeps the GPU. GameMaker and Obsidian
    #     already declare only `dri`, so for them it changes nothing.
    #   * `features=devel` -- Zen and Steam -- switches off Flatpak's own
    #     seccomp blocking of ptrace and perf_event_open.
    #   * `sockets=pcsc` is smartcard access. pcscd is not running on this
    #     machine, so nothing can want it.
    #
    # `ssh-auth` is deliberately absent. Obsidian declares it, the gnome-keyring
    # agent is live at $SSH_AUTH_SOCK, and a git-backed vault genuinely signs
    # with it. Remove it per application through flatpakNarrowingOverrides,
    # where the person removing it knows whether that workflow exists.
    narrowedFlatpak = [
      "--nodevice=all"
      "--device=dri"
      "--disallow=devel"
      "--nosocket=pcsc"
    ];

    # What mujo-trust-launch reads to narrow a GRADUATED Flatpak: the
    # per-application override wins, then the registry tier's profile, then
    # the default.
    narrowingJson = builtins.toJSON {
      default = narrowedFlatpak;
      tiers = cfg.flatpakNarrowing;
      overrides = cfg.flatpakNarrowingOverrides;
    };

    # Everything that needs to know what an application is, or how a runtime
    # starts it, asks this (./mujo-trust-launch.sh; test-mujo-trust-launch.sh).
    trustLaunch = pkgs.writeShellApplication {
      name = "mujo-trust-launch";
      runtimeInputs = with pkgs; [coreutils jq];
      text = builtins.readFile ./mujo-trust-launch.sh;
    };

    # The registry's state machine (./mujo-trust.jq) and its only writer
    # (./mujo-trust-registry.sh). The daemon, the evaluator, the seeder and the
    # root CLI each call the writer with one verb; none of them edits the file.
    # test-mujo-trust-registry.sh drives the same writer offline.
    jqLib = ./mujo-trust.jq;
    trustRegistry = pkgs.writeShellApplication {
      name = "mujo-trust-registry";
      runtimeInputs = with pkgs; [coreutils jq util-linux];
      # The file's own `disable` directive stops applying once this wrapper
      # puts its header above it; the jq programs are single-quoted on purpose.
      excludeShellChecks = ["SC2016"];
      text = builtins.readFile ./mujo-trust-registry.sh;
    };

    # ── privileged daemon ───────────────────────────────────────────────────
    #
    # The registry is root-owned. If the user could write it, an application
    # compromised under that user could simply set its own state to GRADUATED,
    # and every check downstream would believe it. So the unprivileged side
    # gets a socket that exposes only the verbs it is safe to let an
    # application call about itself, and administration stays a root CLI.
    trustHandler = pkgs.writeShellApplication {
      name = "mujo-trustd-handler";
      runtimeInputs = with pkgs; [coreutils jq trustRegistry];
      # $a in `get` is a jq variable, not a shell one.
      excludeShellChecks = ["SC2016"];
      text = ''
        # Which socket this connection came in on. `violation` revokes, so it is
        # accepted only on the root-only report socket the broker writes to; on
        # the users-group socket any process of the user's could otherwise
        # revoke any application by name.
        mode="''${1:?socket mode}"

        # systemd accepts each connection into its own instance of this service,
        # so a client that connects and then says nothing would otherwise hold a
        # root process open for as long as it liked.
        IFS=$'\t' read -t 5 -r verb app arg || exit 0
        [ -n "''${verb:-}" ] || exit 0
        [ -n "''${app:-}" ] || { echo "ERR missing application"; exit 0; }

        case "$mode:$verb" in
          report:violation | user:begin | user:end | user:get) ;;
          *) echo "ERR $verb is not accepted on this socket"; exit 0 ;;
        esac

        # The application names its own key in the registry. Bound it: an
        # unbounded name is a way to grow a root-owned file in /var/lib without
        # ever launching anything.
        [ "''${#app}" -le 128 ] || { echo "ERR application name too long"; exit 0; }

        # Every write is serialised by mujo-trust-registry's own lock, which is
        # why this handler must not hold that lock itself.
        case "$verb" in
          begin)
            # The client supplies the store path or Flatpak active commit path it is
            # about to launch. It could lie, but only to its own cost: an unrecognised
            # path is a new application, and a new application is quarantined.
            case "''${arg:-}" in
              /nix/store/* | /var/lib/flatpak/*) ;;
              *) echo "ERR identity is not a store or flatpak path"; exit 0 ;;
            esac
            mujo-trust-registry begin "$app" "$arg" || echo "ERR registry update failed"
            ;;

          end)
            if mujo-trust-registry end "$app"; then echo "OK"; else echo "ERR registry update failed"; fi
            ;;

          violation)
            # A revoked application still runs -- from its previous known-good
            # path, via `mujo-trust rollback`.
            if mujo-trust-registry violation "$app" "''${arg:-unspecified}"; then
              echo "OK"
            else
              echo "ERR registry update failed"
            fi
            ;;

          get)
            [ -f ${dbFile} ] || { echo "ERR unknown application"; exit 0; }
            jq -r --arg a "$app" '.applications[$a] // "ERR unknown application"' ${dbFile}
            ;;

          *)
            echo "ERR unknown verb"
            ;;
        esac
      '';
    };

    # One accepted connection on either socket; `mode` is which verbs it takes.
    handlerUnit = mode: {
      description = "Mujo trust registry request (${mode})";
      serviceConfig = {
        ExecStart = "${lib.getExe trustHandler} ${mode}";
        StandardInput = "socket";
        StandardOutput = "socket";
        StandardError = "journal";
        # Root, because it owns the registry -- but with everything else it
        # does not need taken away.
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [dbDir];
        PrivateNetwork = true;
        NoNewPrivileges = true;
        RestrictAddressFamilies = ["AF_UNIX"];
        SystemCallFilter = ["@system-service"];
      };
    };

    # ── evaluation ──────────────────────────────────────────────────────────
    #
    # The graduation policy itself is `evaluate` in mujo-trust.jq; this only
    # feeds it the configured periods.
    trustEvaluate = pkgs.writeShellApplication {
      name = "mujo-trust-evaluate";
      runtimeInputs = [trustRegistry];
      text = ''
        [ -f ${dbFile} ] || exit 0
        mujo-trust-registry evaluate \
          ${toString (cfg.observationPeriodHours * 3600)} \
          ${toString (cfg.observingPeriodHours * 3600)}
      '';
    };

    # ── declarative application seeding ─────────────────────────────────────
    #
    # Seeds declared applications and installed Flatpaks into the trust registry.
    # New applications get their initial state and tier; existing applications get
    # their tier synchronised, and any updated store/commit path triggers re-quarantine.
    trustSeed = pkgs.writeShellApplication {
      name = "mujo-trust-seed";
      runtimeInputs = with pkgs; [coreutils trustRegistry trustLaunch];
      text = ''
        seed_app() {
          local name="$1" tier="$2" state="$3"
          local resolved path
          # Not installed (yet) is not an error: it is seeded when it appears.
          resolved=$(mujo-trust-launch resolve "$name" 2>/dev/null) || return 0
          IFS=$'\t' read -r _ _ path <<<"$resolved"
          # One application failing to seed must not stop the rest.
          mujo-trust-registry seed "$name" "$tier" "$state" "$path" || true
        }

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: appCfg: ''
            seed_app ${lib.escapeShellArg name} ${appCfg.tier} ${appCfg.state}
          '')
          cfg.defaultApplications)}

        # Seed installed Flatpak applications (skip if explicitly declared)
        if [ -d /var/lib/flatpak/app ]; then
          for app_dir in /var/lib/flatpak/app/*; do
            if [ -d "$app_dir" ]; then
              f_name=$(basename "$app_dir")
              case "$f_name" in
                ${lib.concatStringsSep "|" (map lib.escapeShellArg (builtins.attrNames cfg.defaultApplications))})
                  ;;
                *)
                  seed_app "$f_name" "medium" "QUARANTINE"
                  ;;
              esac
            fi
          done
        fi
      '';
    };

    # ── user-facing CLI ─────────────────────────────────────────────────────
    mujoTrustCli = pkgs.writeShellApplication {
      name = "mujo-trust";
      runtimeInputs = with pkgs; [coreutils jq socat trustRegistry trustSeed trustLaunch];
      # The single-quoted blocks below are jq programs, and $a / $p / $s are
      # jq variables passed with --arg. shellcheck sees shell parameters that
      # will not expand, which is exactly the intent.
      excludeShellChecks = ["SC2016"];
      text = ''
        DB=${dbFile}
        SOCK=${sockPath}

        usage() {
          cat >&2 <<'USAGE'
        Usage: mujo-trust <command> [args]

        Everyday:
          run <app> [args...]     Launch <app> in the runtime its trust state dictates
          list                    Show every registered application
          status <app>            Show one application's full trust record
          identity <app>          Show the store path <app> currently resolves to

        Administration (root):
          register <app> [tier]   Register <app> (tier: low|medium|high|critical)
          seed                    Seed declarative default applications into registry
          tier <app> <tier>       Change an application's risk tier
          graduate <app>          Promote to GRADUATED (native sandbox)
          quarantine <app>        Force back to QUARANTINE (MicroVM)
          revoke <app>            Mark REVOKED; refuses to launch
          rollback <app>          Return to the previous known-good store path
          evaluate                Apply the graduation policy now
        USAGE
          exit 64
        }

        # The identity (store path or Flatpak commit) <argv> resolves to.
        identity_of() {
          local resolved path
          resolved=$(mujo-trust-launch resolve "$@") || return 1
          IFS=$'\t' read -r _ _ path <<<"$resolved"
          echo "$path"
        }

        ask() {
          printf '%s\t%s\t%s\n' "$1" "$2" "''${3:-}" | socat -T10 - "UNIX-CONNECT:$SOCK"
        }

        require_root() {
          if [ "$(id -u)" -ne 0 ]; then
            echo "mujo-trust: '$1' changes the trust registry and must run as root." >&2
            exit 77
          fi
        }

        # What the application is and how each runtime starts it are both
        # mujo-trust-launch's; this only asks the daemon which runtime, runs
        # the command it is handed, and closes the session.
        cmd_run() {
          [ "$#" -ge 1 ] || usage

          local resolved name path runtime
          resolved=$(mujo-trust-launch resolve "$@") || exit 127
          IFS=$'\t' read -r name _ path <<<"$resolved"

          runtime=$(ask begin "$name" "$path")

          case "$runtime" in
            quarantine | native)
              [ "$runtime" = native ] ||
                echo "mujo-trust: $name is quarantined; launching in the MicroVM domain." >&2
              local -a cmd=()
              mapfile -d "" -t cmd < <(mujo-trust-launch plan "$runtime" "$@")
              [ "''${#cmd[@]}" -gt 0 ] || { ask end "$name" >/dev/null; exit 70; }
              "''${cmd[@]}" || true
              ;;
            denied)
              echo "mujo-trust: $name is REVOKED and will not be launched." >&2
              echo "            'mujo-trust status $name' shows why; 'sudo mujo-trust rollback $name' restores the previous version." >&2
              ask end "$name" >/dev/null
              exit 126
              ;;
            *)
              echo "mujo-trust: trust daemon said: $runtime" >&2
              exit 69
              ;;
          esac

          ask end "$name" >/dev/null
        }

        cmd_list() {
          [ -f "$DB" ] || { echo "No applications registered yet."; return; }
          printf '%-40s %-11s %-9s %-14s %s\n' APPLICATION STATE TIER OBSERVED VIOLATIONS
          jq -r '.applications | to_entries[] |
            [.key, .value.state, .value.tier,
             ((.value.observed_seconds / 3600 * 10 | floor / 10 | tostring) + "h"),
             (.value.violations | tostring)] | @tsv' "$DB" |
          while IFS=$'\t' read -r a s t o v; do
            printf '%-40s %-11s %-9s %-14s %s\n' "$a" "$s" "$t" "$o" "$v"
          done
        }

        case "''${1:-}" in
          run)      shift; cmd_run "$@" ;;
          list)     cmd_list ;;
          status)   [ -n "''${2:-}" ] || usage; jq --arg a "$2" '.applications[$a] // error("not registered")' "$DB" ;;
          identity) [ -n "''${2:-}" ] || usage; identity_of "$2" ;;

          seed)
            require_root seed
            mujo-trust-seed
            echo "Default applications seeded into trust registry."
            ;;

          # Root-only mutations call the registry writer directly. They
          # deliberately do not go through the socket: the socket is what an
          # application can reach, and an application must not be able to
          # promote itself.
          register)
            require_root register
            [ -n "''${2:-}" ] || usage
            resolved=$(mujo-trust-launch resolve "$2") || exit 127
            IFS=$'\t' read -r name _ path <<<"$resolved"
            mujo-trust-registry register "$name" "''${3:-medium}" "$path"
            echo "Registered '$name' as QUARANTINE, tier ''${3:-medium}."
            ;;

          tier)
            require_root tier
            [ -n "''${3:-}" ] || usage
            mujo-trust-registry tier "$2" "$3"
            echo "'$2' is now tier $3."
            ;;

          graduate|quarantine|revoke)
            require_root "$1"
            [ -n "''${2:-}" ] || usage
            case "$1" in
              graduate) state=GRADUATED ;;
              quarantine) state=QUARANTINE ;;
              revoke) state=REVOKED ;;
            esac
            mujo-trust-registry state "$2" "$state"
            echo "'$2' is now $state."
            ;;

          rollback)
            require_root rollback
            [ -n "''${2:-}" ] || usage
            prev=$(mujo-trust-registry rollback "$2")
            echo "'$2' rolled back to $prev and restored to GRADUATED."
            echo "Note: nix will re-select the newer version on the next rebuild unless it is pinned."
            ;;

          evaluate) require_root evaluate; mujo-trust-evaluate; cmd_list ;;
          *)        usage ;;
        esac
      '';
    };

    mujoRunCli = pkgs.writeShellApplication {
      name = "mujo-run";
      runtimeInputs = [mujoTrustCli];
      text = ''
        if [ "$#" -eq 0 ]; then
          cat >&2 <<'USAGE'
        Usage: mujo-run <app> [args...]

        Runs <app> in its designated progressive trust environment:
          - QUARANTINE : Runs in isolated MicroVM (mujo-quarantine-run)
          - GRADUATED  : Runs in native sandbox / Flatpak container (mujo-sandbox-run)
          - REVOKED    : Denied execution
        USAGE
          exit 64
        fi

        exec mujo-trust run "$@"
      '';
    };
  in {
    options.apps.trust = {
      enable =
        lib.mkEnableOption "Mujo progressive trust engine"
        // {default = true;};

      observationPeriodHours = lib.mkOption {
        type = lib.types.int;
        default = 72;
        description = ''
          Accumulated runtime an application must survive in QUARANTINE before
          it becomes eligible for OBSERVING. Counted as time the application was
          actually running, not wall-clock since installation.
        '';
      };

      launcherIntegration = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Route every application launched from the mujō launcher through
          `mujo-trust run`, so the trust state — not the desktop entry — decides
          whether it runs in the quarantine MicroVM or the native sandbox.

          Off by default, and deliberately: with it on, an application that has
          never been graduated launches into a VM the first time it is clicked.
          That is the intended end state, but it changes every launch on the
          machine at once, so it is a switch someone throws on purpose. The
          runbook is in docs/application-trust.md §8.

          A desktop entry that execs `flatpak run [options] <id>` is recorded
          as <id>, not as flatpak (mujo-trust-launch resolves it).
        '';
      };

      observingPeriodHours = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = ''
          Further clean runtime required in OBSERVING before a low- or
          medium-tier application graduates to the native sandbox.
        '';
      };

      flatpakNarrowing = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = {
          low = [];
          medium = narrowedFlatpak;
          high = narrowedFlatpak;
          critical = narrowedFlatpak;
        };
        description = ''
          Subtractive `flatpak run` overrides applied to a GRADUATED Flatpak,
          keyed by the risk tier its registry record carries. A Flatpak cannot
          be nested inside the native sandbox, so these flags are the only way
          the trust engine can enforce a capability profile on one rather than
          take the manifest's word for it.

          `low` is empty on purpose. Steam is the low-tier Flatpak here and it
          genuinely needs `devices=all` for controllers, `multiarch` for 32-bit
          titles and `devel`; narrowing it would break the application to
          protect against the tier that was classified as least risky.

          `high` and `critical` get the same list as `medium` rather than a
          stricter one. Neither tier reaches GRADUATED without someone running
          `mujo-trust graduate` by hand, and shipping an untested stricter
          profile for a path nothing takes today would be guesswork.
        '';
      };

      flatpakNarrowingOverrides = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = {};
        example = lib.literalExpression ''
          {
            # A vault synced over git needs the agent this would otherwise keep.
            "md.obsidian.Obsidian" = ["--nodevice=all" "--device=dri" "--nosocket=ssh-auth"];
            # Opt out entirely: an empty list is a real opt-out, not a
            # fall-through to the tier profile.
            "io.yoyogames.GameMakerBeta" = [];
          }
        '';
        description = ''
          Per-application replacement for the tier profile above, keyed by
          Flatpak application id. The tier says how much the application is
          trusted; this says what it actually needs, which is the wrong thing to
          express by moving an application between tiers.
        '';
      };

      defaultApplications = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            tier = lib.mkOption {
              type = lib.types.enum ["low" "medium" "high" "critical"];
              default = "medium";
              description = "Risk classification tier (Phase 25).";
            };
            state = lib.mkOption {
              type = lib.types.enum ["QUARANTINE" "OBSERVING" "GRADUATED" "REVOKED"];
              default = "QUARANTINE";
              description = "Initial trust state.";
            };
          };
        });
        default = {
          kitty = {
            tier = "low";
            state = "GRADUATED";
          };
          fish = {
            tier = "low";
            state = "GRADUATED";
          };
          cutefetch = {
            tier = "low";
            state = "GRADUATED";
          };
          claude = {
            tier = "high";
            state = "GRADUATED";
          };
          opencode = {
            tier = "high";
            state = "GRADUATED";
          };
          agy = {
            tier = "high";
            state = "GRADUATED";
          };
          herdr = {
            tier = "high";
            state = "GRADUATED";
          };
          "com.valvesoftware.Steam" = {
            tier = "low";
            state = "GRADUATED";
          };
          mujo-vault = {
            tier = "critical";
            state = "QUARANTINE";
          };
          mujo-trust = {
            tier = "critical";
            state = "QUARANTINE";
          };
        };
        description = ''
          Declarative default applications to seed into the progressive trust
          registry. The attribute name *is* the application: a Flatpak
          application id, or a program name on PATH. It is the same name
          `mujo-trust run` records a launch under and the key
          security.mujo.broker.acl grants credentials to.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [mujoTrustCli mujoRunCli trustEvaluate trustSeed];

      # mujo-trust-registry's default jq include path. It lives in /etc, not in
      # the state directory: that directory is an impermanence bind mount, and a
      # tmpfiles symlink placed there was created underneath the mount and then
      # covered by it, so every request died with "module not found".
      environment.etc."mujo/mujo-trust.jq".source = jqLib;
      environment.etc."mujo/flatpak-narrowing.json".text = narrowingJson;

      # A broker violation revokes the registry record whose name equals the
      # ACL key, so a key no launch is recorded under detects nothing.
      assertions = let
        acl = lib.attrByPath ["security" "mujo" "broker" "acl"] {} config;
        undeclared = lib.subtractLists (lib.attrNames cfg.defaultApplications) (lib.attrNames acl);
      in [
        {
          assertion = undeclared == [];
          message = ''
            security.mujo.broker.acl grants credentials to ${lib.concatStringsSep ", " undeclared},
            which apps.trust.defaultApplications does not declare. Declare each one there
            under the name `mujo-trust run` records it by (its Flatpak id or program name).
          '';
        }
      ];

      # The shell reads this marker rather than a build-time value: it runs from
      # the working tree as often as from the store, and a file it can stat is
      # the only channel that is true in both. Absent means off.
      environment.etc."mujo/launcher-integration" =
        lib.mkIf cfg.launcherIntegration {text = "enabled\n";};

      systemd.tmpfiles.rules = [
        "d ${dbDir} 0755 root root -"
        "d /run/mujo 0755 root root -"
      ];

      # Two sockets onto one handler. The users-group one carries what a launch
      # needs (begin/end/get); the root-only one carries `violation`, which
      # revokes, and is what the credential broker reports to. On a shared
      # socket any process of the user's could revoke any application by name.
      systemd.sockets.mujo-trustd = {
        description = "Mujo trust registry socket";
        wantedBy = ["sockets.target"];
        socketConfig = {
          ListenStream = sockPath;
          Accept = "yes";
          SocketMode = "0660";
          SocketUser = "root";
          SocketGroup = "users";
        };
      };

      systemd.sockets.mujo-trust-report = {
        description = "Mujo trust violation report socket";
        wantedBy = ["sockets.target"];
        socketConfig = {
          ListenStream = reportSockPath;
          Accept = "yes";
          SocketMode = "0600";
          SocketUser = "root";
          SocketGroup = "root";
        };
      };

      systemd.services."mujo-trustd@" = handlerUnit "user";
      systemd.services."mujo-trust-report@" = handlerUnit "report";

      systemd.services.mujo-trust-seed = {
        description = "Seed default applications into Mujo trust registry";
        wantedBy = ["multi-user.target"];
        before = ["mujo-trust-evaluate.service"];
        path = [pkgs.coreutils pkgs.jq config.system.path];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe trustSeed;
          RemainAfterExit = true;
        };
      };

      systemd.services.mujo-trust-evaluate = {
        description = "Apply the Mujo graduation policy";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe trustEvaluate;
        };
      };

      systemd.timers.mujo-trust-evaluate = {
        description = "Periodic Mujo trust evaluation";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "10m";
          OnUnitActiveSec = "1h";
          Persistent = true;
        };
      };

      # Deliberately no polkit rule for mujo-trust. There used to be one that
      # returned YES to any wheel user; polkit sees the program and not its
      # arguments, so it covered `graduate` too, and an application running
      # unsandboxed as the user could `pkexec mujo-trust graduate <itself>`
      # without anyone being asked. Reading needs no escalation (the registry
      # is 0644), so every pkexec here is a mutation and gets the PIN prompt.

      # System state owned by root, so it belongs in /var/lib and in the system
      # persistence list rather than under the user's home.
      persistence.directories = [
        {
          directory = dbDir;
          mode = "0755";
        }
      ];
    };
  };
}
