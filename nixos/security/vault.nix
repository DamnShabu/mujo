{pkgs, ...}: {
  flake.nixosModules.security-vault = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.security.mujo;
    user = config.preferences.user.name;
    # The login group, which is `users` here -- not a group named after the user.
    # `chown "$USER:$USER"` fails outright on this system ("invalid group"), and
    # under set -e that aborted `mujo-vault open` after the mount but before the
    # vault subdirectories were created, so credentials/ never existed and the
    # broker could never resolve a secret.
    userGroup = config.users.users.${user}.group;

    # Vault management CLI utility
    mujoVaultCli = pkgs.writeShellApplication {
      name = "mujo-vault";
      runtimeInputs = with pkgs; [cryptsetup e2fsprogs coreutils util-linux su];
      text = ''
        set -euo pipefail

        VAULT_CONTAINER="/persist/secure/mujo-vault.luks"
        MAPPER_NAME="mujo_vault"
        MOUNT_POINT="/run/mujo/vault"
        USER_NAME="${user}"
        USER_GROUP="${userGroup}"

        usage() {
          echo "Usage: mujo-vault {init|open|close|status}"
          echo ""
          echo "Commands:"
          echo "  init    - Create and format the LUKS2 vault container file"
          echo "  open    - Unlock and mount the vault at $MOUNT_POINT"
          echo "  close   - Unmount and lock the vault"
          echo "  status  - Show current vault lock/mount status"
          exit 1
        }

        cmd_init() {
          local size="''${1:-10G}"
          if [ -f "$VAULT_CONTAINER" ]; then
            echo "Error: Vault container already exists at $VAULT_CONTAINER" >&2
            exit 1
          fi
          mkdir -p /persist/secure
          chmod 700 /persist/secure
          echo "Allocating $size container at $VAULT_CONTAINER..."
          fallocate -l "$size" "$VAULT_CONTAINER"
          chmod 600 "$VAULT_CONTAINER"

          echo "Formatting LUKS2 container (Argon2id KDF)..."
          cryptsetup luksFormat --type luks2 --pbkdf argon2id "$VAULT_CONTAINER"

          echo "Opening container for filesystem creation..."
          cryptsetup open "$VAULT_CONTAINER" "$MAPPER_NAME"
          mkfs.ext4 -L mujo_vault "/dev/mapper/$MAPPER_NAME"
          cryptsetup close "$MAPPER_NAME"
          echo "Vault container initialized successfully."
        }

        cmd_open() {
          if [ ! -f "$VAULT_CONTAINER" ]; then
            echo "Error: Vault container not found at $VAULT_CONTAINER. Run 'mujo-vault init' first." >&2
            exit 1
          fi

          if [ -e "/dev/mapper/$MAPPER_NAME" ]; then
            echo "Vault mapper /dev/mapper/$MAPPER_NAME already open."
          else
            echo "Unlocking $VAULT_CONTAINER..."
            cryptsetup open "$VAULT_CONTAINER" "$MAPPER_NAME"
          fi

          mkdir -p "$MOUNT_POINT"
          chmod 700 "$MOUNT_POINT"

          if mountpoint -q "$MOUNT_POINT"; then
            echo "Vault already mounted at $MOUNT_POINT."
          else
            mount -o noatime,nodev,nosuid "/dev/mapper/$MAPPER_NAME" "$MOUNT_POINT"
            chown "$USER_NAME:$USER_GROUP" "$MOUNT_POINT"
            chmod 700 "$MOUNT_POINT"

            # Create default standard subdirectories
            for dir in credentials ssh gpg browser-secrets personal documents application-secrets; do
              mkdir -p "$MOUNT_POINT/$dir"
              chmod 700 "$MOUNT_POINT/$dir"
              chown "$USER_NAME:$USER_GROUP" "$MOUNT_POINT/$dir"
            done
            echo "Vault opened and mounted at $MOUNT_POINT with strict permissions."
          fi
        }

        cmd_close() {
          if mountpoint -q "$MOUNT_POINT"; then
            echo "Unmounting $MOUNT_POINT..."
            umount "$MOUNT_POINT"
          fi

          if [ -e "/dev/mapper/$MAPPER_NAME" ]; then
            echo "Locking vault mapper /dev/mapper/$MAPPER_NAME..."
            cryptsetup close "$MAPPER_NAME"
          fi
          echo "Vault closed successfully."
        }

        cmd_status() {
          echo "=== Mujo Vault Status ==="
          echo "Container: $VAULT_CONTAINER"
          if [ -f "$VAULT_CONTAINER" ]; then
            echo "Container File: Present ($(du -h "$VAULT_CONTAINER" | cut -f1))"
          else
            echo "Container File: Missing"
          fi

          if [ -e "/dev/mapper/$MAPPER_NAME" ]; then
            echo "Mapper Device: Open (/dev/mapper/$MAPPER_NAME)"
          else
            echo "Mapper Device: Closed / Locked"
          fi

          if mountpoint -q "$MOUNT_POINT"; then
            echo "Mountpoint: Mounted at $MOUNT_POINT"
            echo "Permissions: $(stat -c '%a %U:%G' "$MOUNT_POINT")"
          else
            echo "Mountpoint: Not mounted"
          fi
        }

        case "''${1:-}" in
          init)   cmd_init "''${2:-10G}" ;;
          open)   cmd_open ;;
          close)  cmd_close ;;
          status) cmd_status ;;
          *)      usage ;;
        esac
      '';
    };

    # Mujo Secret Broker CLI (Phase 32: Mediated credential access)
    mujoSecretBrokerCli = pkgs.writeShellApplication {
      name = "mujo-secret";
      runtimeInputs = with pkgs; [coreutils jq util-linux];
      text = ''
        set -euo pipefail

        MOUNT_POINT="/run/mujo/vault"
        CRED_DIR="$MOUNT_POINT/credentials"

        usage() {
          echo "Usage: mujo-secret {get <domain> <key>|store <domain> <key>|list <domain>}"
          echo ""
          echo "Commands:"
          echo "  get <domain> <key>   - Retrieve a credential from the vault broker"
          echo "  store <domain> <key> - Store a credential read from stdin"
          echo "  list <domain>        - List available keys in a credential domain"
          echo ""
          echo "store reads the secret from stdin, never from an argument:"
          echo "  printf %s \"\$TOKEN\" | mujo-secret store github token"
          exit 1
        }

        ensure_vault() {
          if [ ! -d "$MOUNT_POINT" ] || ! mountpoint -q "$MOUNT_POINT"; then
            echo "Error: Mujo Vault is locked. Run 'mujo-vault open' to unlock." >&2
            exit 1
          fi
        }

        cmd_get() {
          local domain="''${1:-}"
          local key="''${2:-}"
          if [ -z "$domain" ] || [ -z "$key" ]; then usage; fi
          ensure_vault
          local secret_file="$CRED_DIR/$domain/$key"
          if [ ! -f "$secret_file" ]; then
            echo "Error: Secret '$key' not found in domain '$domain'." >&2
            exit 1
          fi
          cat "$secret_file"
        }

        # The secret arrives on stdin. Passing it as an argument would publish it
        # in /proc/<pid>/cmdline to every process on the machine and write it to
        # the caller's shell history -- both ruled out by docs/threat-model.md.
        cmd_store() {
          local domain="''${1:-}"
          local key="''${2:-}"
          if [ -z "$domain" ] || [ -z "$key" ]; then usage; fi
          if [ -t 0 ]; then
            echo "Error: no secret on stdin. Pipe it in, e.g." >&2
            echo "  printf %s \"\$TOKEN\" | mujo-secret store $domain $key" >&2
            exit 1
          fi
          ensure_vault
          local target_dir="$CRED_DIR/$domain"
          mkdir -p "$target_dir"
          chmod 700 "$target_dir"
          local secret_file="$target_dir/$key"
          # Create with a restrictive mode before any bytes land in it, so the
          # secret is never briefly readable at the default umask.
          (umask 077 && cat > "$secret_file")
          echo "Stored secret '$key' in domain '$domain'."
        }

        cmd_list() {
          local domain="''${1:-}"
          if [ -z "$domain" ]; then usage; fi
          ensure_vault
          local target_dir="$CRED_DIR/$domain"
          if [ -d "$target_dir" ]; then
            ls -1 "$target_dir"
          else
            echo "No secrets found in domain '$domain'."
          fi
        }

        case "''${1:-}" in
          get)   cmd_get "''${2:-}" "''${3:-}" ;;
          store) cmd_store "''${2:-}" "''${3:-}" ;;
          list)  cmd_list "''${2:-}" ;;
          *)     usage ;;
        esac
      '';
    };
  in {
    config = lib.mkIf (cfg.enable && cfg.vault.enable) {
      environment.systemPackages = [
        mujoVaultCli
        mujoSecretBrokerCli
        pkgs.cryptsetup
      ];

      # Allow users in wheel group to unlock/lock vault without password prompt in GUI
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.policykit.exec" &&
              (action.lookup("program") == "${lib.getExe mujoVaultCli}" ||
               action.lookup("program") == "/run/current-system/sw/bin/mujo-vault") &&
              subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
        });
      '';

      # /persist is the btrfs subvolume that survives the root wipe, so a path
      # already under it needs no impermanence entry -- declaring one asked
      # impermanence to bind /persist/system/persist/secure onto /persist/secure,
      # which put the container two levels deeper than every document says it
      # lives. tmpfiles just creates the directory, root-only, where it belongs.
      systemd.tmpfiles.rules = [
        "d /persist/secure 0700 root root -"
      ];
    };
  };
}
