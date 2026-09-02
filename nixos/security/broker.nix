{...}: {
  flake.nixosModules.security-broker = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.security.mujo;
    brokerCfg = cfg.broker;
    user = config.preferences.user.name;

    sockDir = "/run/mujo/secrets";
    vaultMount = "/run/mujo/vault";
    # nixos/apps/trust.nix owns this socket. Connecting to it needs write
    # permission on the socket inode only, which ProtectSystem=strict does not
    # take away: a read-only superblock rejects MAY_WRITE for regular files,
    # directories and symlinks, not for sockets.
    trustSock = "/run/mujo/trust.sock";

    # ── the broker ──────────────────────────────────────────────────────────
    #
    # Phase 32: an application asks for one credential and receives one
    # credential. It never learns where the vault is mounted, never sees the
    # other domains, and cannot enumerate what it was not granted.
    #
    # The hard part is knowing *which* application is asking. A name sent over
    # the wire is worthless -- anything can claim to be git. So identity is a
    # filesystem capability instead: every entry in the ACL gets its own socket,
    # and mujo-sandbox-run binds exactly one of them into the sandbox's mount
    # namespace. An application can only reach the socket it was handed, and
    # that socket's grants are fixed at build time.
    handlerFor = app: grants:
      pkgs.writeShellApplication {
        name = "mujo-secretd-${app}";
        runtimeInputs = with pkgs; [coreutils util-linux socat];
        text = ''
          GRANTS="${lib.concatStringsSep " " grants}"

          IFS=$'\t' read -r domain key || exit 0
          if [ -z "''${domain:-}" ] || [ -z "''${key:-}" ]; then
            echo "ERR malformed request"
            exit 0
          fi

          # A request is a security event whether or not it is granted, so both
          # outcomes are logged -- but only ever the name of the credential.
          # Logging a value here would put the secret in the journal, which
          # docs/threat-model.md rules out explicitly.
          log() { echo "mujo-secretd[${app}]: $1 $domain/$key" >&2; }

          granted=no
          for g in $GRANTS; do
            if [ "$g" = "$domain/$key" ]; then
              granted=yes
              break
            fi
          done

          if [ "$granted" != yes ]; then
            log DENY
            # Phase 21/40. An application reaching for a credential it was never
            # granted is a boundary violation, not a typo: the socket it is
            # talking to is the only one it can see, and its grants were fixed
            # at build time. Reporting it here is what makes the trust engine's
            # `violation` verb a detector rather than an interface nobody calls
            # -- the engine revokes, and `mujo-trust rollback` is the way back.
            #
            # Only the credential's *name* crosses, never its value, and a
            # trust daemon that is down must not turn a denial into a hang.
            printf 'violation\t%s\tdenied credential request %s\n' \
              ${lib.escapeShellArg app} "$domain/$key" |
              socat -T5 - UNIX-CONNECT:${trustSock} >/dev/null 2>&1 || true
            echo "ERR not granted"
            exit 0
          fi

          if ! mountpoint -q ${vaultMount}; then
            log UNAVAILABLE
            echo "ERR vault is locked"
            exit 0
          fi

          secret="${vaultMount}/credentials/$domain/$key"
          if [ ! -f "$secret" ]; then
            log MISSING
            echo "ERR no such credential"
            exit 0
          fi

          log GRANT
          cat "$secret"
        '';
      };

    brokerSockets = lib.mapAttrs' (app: grants:
      lib.nameValuePair "mujo-secretd-${app}" {
        description = "Mujo credential broker socket for ${app}";
        wantedBy = ["sockets.target"];
        socketConfig = {
          ListenStream = "${sockDir}/${app}.sock";
          Accept = "yes";
          SocketMode = "0660";
          SocketUser = "root";
          SocketGroup = "users";
        };
      })
    brokerCfg.acl;

    brokerServices = lib.mapAttrs' (app: grants:
      lib.nameValuePair "mujo-secretd-${app}@" {
        description = "Mujo credential request for ${app}";
        serviceConfig = {
          ExecStart = lib.getExe (handlerFor app grants);
          StandardInput = "socket";
          StandardOutput = "socket";
          StandardError = "journal";
          # Root, because only root can read the vault -- but stripped of
          # everything it does not need to hand over one file.
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateNetwork = true;
          PrivateDevices = true;
          NoNewPrivileges = true;
          RestrictAddressFamilies = ["AF_UNIX"];
          SystemCallFilter = ["@system-service"];
          # The vault mount has to stay visible to this unit, and only to it.
          #
          # The `-` prefix makes it optional. Without it, a locked vault means
          # the mount source does not exist, systemd fails to set up the
          # namespace, and the unit never starts -- so the client sees a reset
          # connection instead of the handler's "vault is locked", and the
          # DENY path never runs either. The broker has to be able to answer
          # while the vault is closed; that is most of its life.
          BindReadOnlyPaths = ["-${vaultMount}"];
        };
      })
    brokerCfg.acl;

    # The client an application inside a sandbox uses. It knows one socket path
    # and nothing else -- not the vault, not the ACL, not the other domains.
    mujoCredential = pkgs.writeShellApplication {
      name = "mujo-credential";
      runtimeInputs = with pkgs; [coreutils socat];
      text = ''
        SOCK=''${MUJO_SECRET_SOCKET:-/run/mujo/secret.sock}

        if [ "$#" -ne 2 ]; then
          cat >&2 <<'USAGE'
        Usage: mujo-credential <domain> <key>

        Asks the Mujo credential broker for one credential and writes it to
        stdout. Only the credentials this application was granted are reachable;
        the vault itself is not.
        USAGE
          exit 64
        fi

        if [ ! -S "$SOCK" ]; then
          echo "mujo-credential: no broker socket at $SOCK (this application was granted no credentials)" >&2
          exit 77
        fi

        reply=$(printf '%s\t%s\n' "$1" "$2" | socat -T10 - "UNIX-CONNECT:$SOCK")
        case "$reply" in
          "ERR "*)
            echo "mujo-credential: ''${reply#ERR }" >&2
            exit 1
            ;;
        esac
        printf '%s' "$reply"
      '';
    };
  in {
    options.security.mujo.broker = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the Mujo credential broker (mediated vault access)";
      };

      acl = lib.mkOption {
        type = with lib.types; attrsOf (listOf str);
        default = {};
        example = lib.literalExpression ''
          {
            git = ["github/token"];
            mail = ["fastmail/app-password" "fastmail/smtp"];
          }
        '';
        description = ''
          Which credentials each application may request, as
          `<application> = [ "<domain>/<key>" ... ]`.

          Empty by default: an application with no entry here gets no broker
          socket at all, so it cannot ask for anything. Grants are fixed at
          build time and cannot be widened at runtime.
        '';
      };
    };

    config = lib.mkIf (cfg.enable && brokerCfg.enable) {
      environment.systemPackages = [mujoCredential];

      systemd.tmpfiles.rules = [
        "d /run/mujo 0755 root root -"
        # Traversable so mujo-sandbox-run, which runs as the user, can bind a
        # socket out of it. The sockets themselves are the access control, and
        # the boundary that matters is the sandbox's mount namespace: an
        # application sees the one socket it was given and no others.
        "d ${sockDir} 0755 root root -"
      ];

      systemd.sockets = brokerSockets;
      systemd.services = brokerServices;

      assertions = [
        {
          assertion =
            lib.all (g: builtins.match "[^/]+/[^/]+" g != null)
            (lib.flatten (lib.attrValues brokerCfg.acl));
          message = ''
            security.mujo.broker.acl grants must be exactly "<domain>/<key>".
            A grant with no slash, or with more than one, would never match a
            request and would silently deny instead of failing here.
          '';
        }
      ];
    };
  };
}
