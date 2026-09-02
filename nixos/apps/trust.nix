{...}: {
  flake.nixosModules.app-trust = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.apps.trust;
    user = config.preferences.user.name;

    dbDir = "/var/lib/mujo-trust";
    dbFile = "${dbDir}/registry.json";
    sockPath = "/run/mujo/trust.sock";

    # The shared jq library lives in /etc, not in the state directory: that
    # directory is an impermanence bind mount, and a tmpfiles symlink placed
    # there was created underneath the mount and then covered by it, so every
    # request died with "module not found".
    jqDir = "/etc/mujo";

    # Shared by the daemon and the root CLI. Kept in one place because a trust
    # record written by one and read by the other has to agree on its shape.
    jqLib = pkgs.writeText "mujo-trust.jq" ''
      def now_iso: (now | todate);

      def new_record($name; $tier; $path):
        { name: $name,
          tier: $tier,
          state: "QUARANTINE",
          store_path: $path,
          previous_store_path: null,
          observed_seconds: 0,
          session_started: null,
          registered_at: now_iso,
          last_evaluated: now_iso,
          violations: 0,
          violation_log: [] };

      # An application is identified by its store path, which is a hash of its
      # content and its whole build closure. A rebuilt or updated package is a
      # different application, and docs/application-trust.md §5 requires it to
      # start its evaluation over -- while the path that was trusted stays
      # recorded, because that is what a rollback returns to.
      def requarantine($path):
        .previous_store_path = .store_path
        | .store_path = $path
        | .state = "QUARANTINE"
        | .observed_seconds = 0
        | .session_started = null
        | .last_evaluated = now_iso;

      # The runtime a state maps to. This is the whole point of the engine:
      # nothing else in the system decides where an application runs.
      def runtime_for:
        if .state == "REVOKED" then "denied"
        elif .state == "GRADUATED" then "native"
        else "quarantine" end;
    '';

    # ── privileged daemon ───────────────────────────────────────────────────
    #
    # The registry is root-owned. If the user could write it, an application
    # compromised under that user could simply set its own state to GRADUATED,
    # and every check downstream would believe it. So the unprivileged side
    # gets a socket that exposes only the verbs it is safe to let an
    # application call about itself, and administration stays a root CLI.
    trustHandler = pkgs.writeShellApplication {
      name = "mujo-trustd-handler";
      runtimeInputs = with pkgs; [coreutils jq];
      # $a / $p in the blocks below are jq variables, not shell ones.
      excludeShellChecks = ["SC2016"];
      text = ''
        umask 022
        mkdir -p ${dbDir}
        [ -f ${dbFile} ] || echo '{"applications":{}}' > ${dbFile}

        # jq cannot write in place, and a half-written registry is worse than a
        # stale one: swap it atomically or not at all.
        commit() {
          local tmp
          tmp=$(mktemp ${dbDir}/.registry.XXXXXX)
          if jq -L${jqDir} "$@" ${dbFile} > "$tmp"; then
            chmod 644 "$tmp"
            mv "$tmp" ${dbFile}
          else
            rm -f "$tmp"
            return 1
          fi
        }

        IFS=$'\t' read -r verb app arg || exit 0
        [ -n "''${verb:-}" ] || exit 0
        [ -n "''${app:-}" ] || { echo "ERR missing application"; exit 0; }

        case "$verb" in
          begin)
            # The client supplies the store path or Flatpak active commit path it is
            # about to launch. It could lie, but only to its own cost: an unrecognised
            # path is a new application, and a new application is quarantined.
            case "''${arg:-}" in
              /nix/store/* | /var/lib/flatpak/*) ;;
              *) echo "ERR identity is not a store or flatpak path"; exit 0 ;;
            esac

            commit --arg a "$app" --arg p "$arg" '
              include "mujo-trust";
              if .applications[$a] == null
              then .applications[$a] = new_record($a; "medium"; $p)
              elif .applications[$a].store_path != $p
              then .applications[$a] |= requarantine($p)
              else . end
              # Only one accumulator per application: parallel launches must not
              # let an application bank several hours per hour of real time.
              | if .applications[$a].session_started == null
                then .applications[$a].session_started = now
                else . end
            ' || { echo "ERR registry update failed"; exit 0; }

            jq -L${jqDir} -r --arg a "$app" \
              'include "mujo-trust"; .applications[$a] | runtime_for' ${dbFile}
            ;;

          end)
            commit --arg a "$app" '
              include "mujo-trust";
              if .applications[$a].session_started == null then . else
                .applications[$a].observed_seconds +=
                  ((now - .applications[$a].session_started) | floor)
                | .applications[$a].session_started = null
              end
            ' || { echo "ERR registry update failed"; exit 0; }
            echo "OK"
            ;;

          violation)
            # Any reported boundary violation revokes immediately. Deciding
            # whether it was a false positive is a human's job, and a revoked
            # application still runs -- from its previous known-good path, via
            # `mujo-trust rollback`.
            commit --arg a "$app" --arg r "''${arg:-unspecified}" '
              include "mujo-trust";
              if .applications[$a] == null then . else
                .applications[$a].violations += 1
                | .applications[$a].state = "REVOKED"
                | .applications[$a].last_evaluated = now_iso
                | .applications[$a].violation_log +=
                    [{ at: now_iso, reason: $r }]
              end
            ' || { echo "ERR registry update failed"; exit 0; }
            echo "OK"
            ;;

          get)
            jq -r --arg a "$app" '.applications[$a] // "ERR unknown application"' ${dbFile}
            ;;

          *)
            echo "ERR unknown verb"
            ;;
        esac
      '';
    };

    # ── evaluation ──────────────────────────────────────────────────────────
    #
    # Time alone never graduates anything (Phase 20): the policy below also
    # requires a clean violation record, and refuses to move CRITICAL past
    # quarantine or HIGH past observation without a person saying so.
    trustEvaluate = pkgs.writeShellApplication {
      name = "mujo-trust-evaluate";
      runtimeInputs = with pkgs; [coreutils jq];
      excludeShellChecks = ["SC2016"];
      text = ''
        [ -f ${dbFile} ] || exit 0
        tmp=$(mktemp ${dbDir}/.registry.XXXXXX)
        # Swap the registry atomically or leave it alone: a half-written
        # evaluation would be worse than a stale one.
        if jq -L${jqDir} \
          --argjson quarantine ${toString (cfg.observationPeriodHours * 3600)} \
          --argjson observing ${toString (cfg.observingPeriodHours * 3600)} '
          include "mujo-trust";
          .applications |= with_entries(
            .value |= (
              # Bank what a still-running application has accumulated so far.
              # Time was otherwise only credited when a session ended, so
              # anything long-running sat at the same number forever.
              (if .session_started == null then .
               else .observed_seconds += ((now - .session_started) | floor)
                    | .session_started = now
               end)
              | if .violations > 0 then .
              elif .state == "QUARANTINE"
                   and .observed_seconds >= $quarantine
                   and .tier != "critical"
              then .state = "OBSERVING" | .last_evaluated = now_iso
              elif .state == "OBSERVING"
                   and .observed_seconds >= ($quarantine + $observing)
                   and (.tier == "low" or .tier == "medium")
              then .state = "GRADUATED" | .last_evaluated = now_iso
              else . end
            )
          )
        ' ${dbFile} > "$tmp"
        then
          chmod 644 "$tmp"
          mv "$tmp" ${dbFile}
        else
          rm -f "$tmp"
        fi
      '';
    };

    # ── declarative application seeding ─────────────────────────────────────
    #
    # Seeds declared applications and installed Flatpaks into the trust registry.
    # New applications get their initial state and tier; existing applications get
    # their tier synchronised, and any updated store/commit path triggers re-quarantine.
    trustSeed = pkgs.writeShellApplication {
      name = "mujo-trust-seed";
      runtimeInputs = with pkgs; [coreutils jq];
      excludeShellChecks = ["SC2016"];
      text = ''
        umask 022
        mkdir -p ${dbDir}
        [ -f ${dbFile} ] || echo '{"applications":{}}' > ${dbFile}

        identity_of() {
          local app="$1"
          if [ "$app" = "flatpak" ] && [ "''${2:-}" = "run" ] && [ -n "''${3:-}" ]; then
            app="$3"
          fi

          if [ -d "/var/lib/flatpak/app/$app" ]; then
            local active="/var/lib/flatpak/app/$app/current/active"
            if [ -e "$active" ]; then
              readlink -f "$active"
              return 0
            fi
          fi

          local bin
          bin=$(type -P "$app") || return 1
          [ -n "$bin" ] || return 1
          readlink -f "$bin"
        }

        seed_app() {
          local name="$1" tier="$2" state="$3" bin="$4"
          local path
          path=$(identity_of "$bin") || return 0
          [ -n "$path" ] || return 0

          local tmp
          tmp=$(mktemp ${dbDir}/.registry.XXXXXX)
          if jq -L${jqDir} --arg a "$name" --arg t "$tier" --arg s "$state" --arg p "$path" '
            include "mujo-trust";
            if .applications[$a] == null then
              .applications[$a] = (new_record($a; $t; $p) | .state = $s)
            elif .applications[$a].store_path != $p then
              .applications[$a] |= requarantine($p)
              | (if $s != "QUARANTINE" then .applications[$a].state = $s else . end)
            else
              .applications[$a].tier = $t
              | (if $s != "QUARANTINE" then .applications[$a].state = $s else . end)
            end
          ' ${dbFile} > "$tmp"; then
            chmod 644 "$tmp"
            mv "$tmp" ${dbFile}
          else
            rm -f "$tmp"
          fi
        }

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: appCfg: ''
            seed_app "${name}" "${appCfg.tier}" "${appCfg.state}" "${
              if appCfg.binary != ""
              then appCfg.binary
              else name
            }"
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
                  active="$app_dir/current/active"
                  if [ -e "$active" ]; then
                    seed_app "$f_name" "medium" "QUARANTINE" "$f_name"
                  fi
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
      runtimeInputs = with pkgs; [coreutils jq socat trustSeed];
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

        extract_flatpak_app() {
          local in_run=0
          for arg in "$@"; do
            case "$arg" in
              *flatpak) in_run=1 ;;
              run) in_run=1 ;;
              -*) ;;
              *)
                if [ "$in_run" -eq 1 ] && [ -d "/var/lib/flatpak/app/$arg" ]; then
                  echo "$arg"
                  return 0
                elif [ -d "/var/lib/flatpak/app/$arg" ]; then
                  echo "$arg"
                  return 0
                fi
                ;;
            esac
          done
          return 1
        }

        # Resolve the launched name to its identity (Nix store path or Flatpak commit).
        identity_of() {
          local app="$1"
          local fp_app=""
          if fp_app=$(extract_flatpak_app "$@"); then
            app="$fp_app"
          fi

          if [ -d "/var/lib/flatpak/app/$app" ]; then
            local active="/var/lib/flatpak/app/$app/current/active"
            if [ -e "$active" ]; then
              readlink -f "$active"
              return 0
            fi
          fi

          local bin
          bin=$(type -P "$app") || return 1
          [ -n "$bin" ] || return 1
          readlink -f "$bin"
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

        # Root-only mutations write the registry directly. They deliberately do
        # not go through the socket: the socket is what an application can
        # reach, and an application must not be able to promote itself.
        edit_db() {
          local tmp
          tmp=$(mktemp ${dbDir}/.registry.XXXXXX)
          if jq -L${jqDir} "$@" "$DB" > "$tmp"; then
            chmod 644 "$tmp"
            mv "$tmp" "$DB"
          else
            rm -f "$tmp"
            exit 1
          fi
        }

        cmd_run() {
          local app="''${1:-}"
          [ -n "$app" ] || usage

          local app_name="$app"
          local is_flatpak=0
          local fp_app=""
          if fp_app=$(extract_flatpak_app "$@"); then
            app_name="$fp_app"
            is_flatpak=1
          elif [ -d "/var/lib/flatpak/app/$app" ]; then
            is_flatpak=1
          fi

          local path
          if ! path=$(identity_of "$@"); then
            echo "mujo-trust: $app: not found" >&2
            exit 127
          fi

          local runtime
          runtime=$(ask begin "$app_name" "$path")

          case "$runtime" in
            quarantine)
              echo "mujo-trust: $app_name is quarantined; launching in the MicroVM domain." >&2
              if [ "$is_flatpak" -eq 1 ]; then
                case "$app" in
                  *flatpak)
                    mujo-quarantine-run "$@" || true
                    ;;
                  *)
                    mujo-quarantine-run flatpak run "$@" || true
                    ;;
                esac
              else
                mujo-quarantine-run "$@" || true
              fi
              ;;
            native)
              if [ "$is_flatpak" -eq 1 ]; then
                case "$app" in
                  *flatpak)
                    "$@" || true
                    ;;
                  *)
                    flatpak run "$@" || true
                    ;;
                esac
              else
                mujo-sandbox-run "$@" || true
              fi
              ;;
            denied)
              echo "mujo-trust: $app_name is REVOKED and will not be launched." >&2
              echo "            'mujo-trust status $app_name' shows why; 'sudo mujo-trust rollback $app_name' restores the previous version." >&2
              ask end "$app_name" >/dev/null
              exit 126
              ;;
            *)
              echo "mujo-trust: trust daemon said: $runtime" >&2
              exit 69
              ;;
          esac

          ask end "$app_name" >/dev/null
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

          register)
            require_root register
            [ -n "''${2:-}" ] || usage
            path=$(identity_of "$2") || { echo "mujo-trust: $2: not found" >&2; exit 127; }
            edit_db --arg a "$2" --arg t "''${3:-medium}" --arg p "$path" \
              'include "mujo-trust"; .applications[$a] = new_record($a; $t; $p)'
            echo "Registered '$2' as QUARANTINE, tier ''${3:-medium}."
            ;;

          tier)
            require_root tier
            [ -n "''${3:-}" ] || usage
            edit_db --arg a "$2" --arg t "$3" '.applications[$a].tier = $t'
            echo "'$2' is now tier $3."
            ;;

          graduate|quarantine|revoke)
            require_root "$1"
            [ -n "''${2:-}" ] || usage
            state=$(echo "$1" | tr '[:lower:]' '[:upper:]')
            [ "$state" = "GRADUATE" ] && state=GRADUATED
            [ "$state" = "REVOKE" ] && state=REVOKED
            edit_db --arg a "$2" --arg s "$state" \
              'include "mujo-trust"; .applications[$a].state = $s | .applications[$a].last_evaluated = now_iso'
            echo "'$2' is now $state."
            ;;

          rollback)
            require_root rollback
            [ -n "''${2:-}" ] || usage
            prev=$(jq -r --arg a "$2" '.applications[$a].previous_store_path // ""' "$DB")
            if [ -z "$prev" ] || [ ! -e "$prev" ]; then
              echo "mujo-trust: no previous known-good version of '$2' is still in the store." >&2
              exit 1
            fi
            # The old closure is still in the Nix store until it is garbage
            # collected, which is what makes rollback a lookup rather than a
            # rebuild.
            edit_db --arg a "$2" --arg p "$prev" '
              include "mujo-trust";
              .applications[$a].store_path = $p
              | .applications[$a].previous_store_path = null
              | .applications[$a].state = "GRADUATED"
              | .applications[$a].violations = 0
              | .applications[$a].last_evaluated = now_iso'
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

          Known limitation: applications whose desktop entry execs a launcher
          (Flatpak's `flatpak run …`) are identified as that launcher, not as
          themselves, so they all share one trust record. Keep those out of the
          engine until the entry resolves to the application's own store path.
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
            binary = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Binary name or command on PATH to resolve store path from.";
            };
          };
        });
        default = {
          kitty = {
            tier = "low";
            state = "GRADUATED";
            binary = "kitty";
          };
          fish = {
            tier = "low";
            state = "GRADUATED";
            binary = "fish";
          };
          cutefetch = {
            tier = "low";
            state = "GRADUATED";
            binary = "cutefetch";
          };
          claude = {
            tier = "high";
            state = "GRADUATED";
            binary = "claude";
          };
          opencode = {
            tier = "high";
            state = "GRADUATED";
            binary = "opencode";
          };
          agy = {
            tier = "high";
            state = "GRADUATED";
            binary = "agy";
          };
          herdr = {
            tier = "high";
            state = "GRADUATED";
            binary = "herdr";
          };
          "com.valvesoftware.Steam" = {
            tier = "low";
            state = "GRADUATED";
            binary = "com.valvesoftware.Steam";
          };
          mujo-vault = {
            tier = "critical";
            state = "QUARANTINE";
            binary = "mujo-vault";
          };
          mujo-trust = {
            tier = "critical";
            state = "QUARANTINE";
            binary = "mujo-trust";
          };
        };
        description = "Declarative default applications to seed into the progressive trust registry.";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [mujoTrustCli mujoRunCli trustEvaluate trustSeed];

      # jq include path: the daemon, the CLI and the evaluator all load the same
      # definitions from /etc/mujo, so a record written by one is read the same
      # way by the others.
      environment.etc."mujo/mujo-trust.jq".source = jqLib;

      # The shell reads this marker rather than a build-time value: it runs from
      # the working tree as often as from the store, and a file it can stat is
      # the only channel that is true in both. Absent means off.
      environment.etc."mujo/launcher-integration" =
        lib.mkIf cfg.launcherIntegration {text = "enabled\n";};

      systemd.tmpfiles.rules = [
        "d ${dbDir} 0755 root root -"
        "d /run/mujo 0755 root root -"
      ];

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

      systemd.services."mujo-trustd@" = {
        description = "Mujo trust registry request";
        serviceConfig = {
          ExecStart = lib.getExe trustHandler;
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

      # Allow users in wheel group to manage application trust without password prompt in GUI
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.policykit.exec" &&
              subject.isInGroup("wheel")) {
            var prog = action.lookup("program");
            if (prog && (prog.indexOf("mujo-trust") !== -1 || prog == "/run/current-system/sw/bin/mujo-trust")) {
              return polkit.Result.YES;
            }
          }
        });
      '';

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
