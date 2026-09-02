{pkgs, ...}: {
  flake.nixosModules.security-storage = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.security.mujo;
    user = config.preferences.user.name;

    # Sensitive Data Inventory Auditor (docs/storage-model.md, Phase 6).
    #
    # The paths below follow the impermanence layout: a persisted home directory
    # lives at /persist/userdata/home/<user>/..., not /persist/home/<user>/...
    # The earlier version of this tool audited the latter, which does not exist
    # on this system, so every check reported "NOT FOUND (CLEAN)" regardless of
    # what was actually sitting on disk.
    mujoInventoryCli = pkgs.writeShellApplication {
      name = "mujo-inventory";
      runtimeInputs = with pkgs; [coreutils findutils gnugrep util-linux];
      text = ''
        set -euo pipefail

        USER_DATA="/persist/userdata/home/${user}"
        USER_CACHE="/persist/usercache/home/${user}"
        SYSTEM="/persist/system"
        FOUND_LEAKS=0

        echo "================================================="
        echo "   MUJO SENSITIVE DATA INVENTORY & AUDIT        "
        echo "================================================="

        # audit_path <description> <path> <pattern|""> <classification>
        # An empty pattern means the path's mere existence is the finding.
        audit_path() {
          local desc="$1" path="$2" pattern="$3" classification="$4"

          printf '%-46s ' "$desc"
          if [ ! -e "$path" ]; then
            echo "ABSENT"
            return
          fi
          if [ -z "$pattern" ]; then
            echo "PRESENT [$classification]"
            FOUND_LEAKS=$((FOUND_LEAKS + 1))
            return
          fi
          if grep -rIlq --binary-files=without-match -- "$pattern" "$path" 2>/dev/null; then
            echo "PLAINTEXT FOUND [$classification]"
            FOUND_LEAKS=$((FOUND_LEAKS + 1))
          else
            echo "CLEAN"
          fi
        }

        echo ""
        echo "--- 1. Cryptographic keys ---"
        audit_path "OpenSSH private keys" "$USER_DATA/.ssh" "PRIVATE KEY" "MIGRATE TO VAULT"
        audit_path "GPG private keys" "$USER_DATA/.gnupg" "PGP PRIVATE KEY BLOCK" "MIGRATE TO VAULT"
        audit_path "Host SSH keys" "$SYSTEM/etc/ssh" "PRIVATE KEY" "PERSISTENT + ACCEPTED"
        audit_path "pass / password-store" "$USER_DATA/.password-store" "" "MIGRATE TO VAULT"

        echo ""
        echo "--- 2. Browser and keyring secrets ---"
        audit_path "Zen / Firefox saved logins" "$USER_DATA/.zen" "encryptedPassword" "MIGRATE TO VAULT"
        audit_path "GNOME keyrings" "$USER_DATA/.local/share/keyrings" "" "PERSISTENT + ENCRYPTED"
        audit_path "Browser cache (session tokens)" "$USER_CACHE/.cache/zen" "" "SHOULD BE EPHEMERAL"

        echo ""
        echo "--- 3. Developer and cloud credentials ---"
        audit_path "AWS credentials" "$USER_DATA/.aws" "aws_secret_access_key" "MIGRATE TO VAULT"
        audit_path "GitHub CLI tokens" "$USER_DATA/.config/gh" "oauth_token" "MIGRATE TO VAULT"
        audit_path "Docker registry auth" "$USER_DATA/.docker" "\"auth\"" "MIGRATE TO VAULT"
        audit_path "NetworkManager PSKs" "$SYSTEM/etc/NetworkManager/system-connections" "psk=" "PERSISTENT + ACCEPTED"

        echo ""
        echo "--- 4. Memory images on disk ---"
        cores=$(find "$SYSTEM" /var/lib/systemd/coredump -type f \
          \( -name 'core.*' -o -name '*.core' \) 2>/dev/null | wc -l)
        printf '%-46s ' "Core dumps on persistent storage"
        if [ "$cores" -eq 0 ]; then
          echo "CLEAN"
        else
          echo "$cores FOUND [PLAINTEXT RAM IMAGES]"
          FOUND_LEAKS=$((FOUND_LEAKS + 1))
        fi

        printf '%-46s ' "Unencrypted persistent swap"
        unenc=0
        while read -r dev _; do
          case "$dev" in Filename | "") continue ;; esac
          name=''${dev#/dev/}
          case "$name" in zram*) continue ;; esac
          grep -qs '^CRYPT-' "/sys/class/block/$name/dm/uuid" || unenc=$((unenc + 1))
        done < /proc/swaps
        if [ "$unenc" -eq 0 ]; then
          echo "CLEAN"
        else
          echo "$unenc DEVICE(S) [PAGES SURVIVE POWER-OFF]"
          FOUND_LEAKS=$((FOUND_LEAKS + 1))
        fi

        echo ""
        echo "================================================="
        if [ "$FOUND_LEAKS" -eq 0 ]; then
          echo "  CLEAN: no sensitive plaintext outside the vault"
          echo "================================================="
        else
          echo "  $FOUND_LEAKS finding(s) outside the encrypted vault"
          echo "  Migrate with: sudo mujo-vault open"
          echo "                printf %s \"\$SECRET\" | mujo-secret store <domain> <key>"
          echo "================================================="
          exit 1
        fi
      '';
    };
  in {
    options.security.mujo.storage = {
      encryptedSwap = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Require every persistent swap device to be encrypted, and forbid a
          resume device. Enforced as an assertion rather than by rewriting the
          disk layout: the swap partition is declared in the host's disko
          configuration, and silently re-keying a device this module does not own
          is how a machine stops booting. Turning this off accepts that swap can
          retain plaintext across a power cycle.
        '';
      };
    };

    config = lib.mkIf (cfg.enable && cfg.storage.enable) {
      environment.systemPackages = [
        mujoInventoryCli
      ];

      # /tmp used to be in the impermanence persisted list, which made it a bind
      # mount from /persist/system/tmp: every scratch file an application wrote
      # there landed on unencrypted disk and survived reboots. It is the default
      # scratch directory for practically everything, so that quietly
      # contradicted the invariant above.
      #
      # Backing it with RAM closes it at the source rather than by cleaning up
      # afterwards. What pressure does push out goes to swap, which is re-keyed
      # with a random key every boot -- so the worst case is still ciphertext
      # nobody can read after a power cycle.
      #
      # Default size is half of RAM (31G of 62G here), which is ample for Nix
      # builds; lower boot.tmp.tmpfsSize if a build ever needs the headroom back.
      boot.tmp.useTmpfs = lib.mkDefault true;

      # Invariant: no plaintext RAM image ever reaches disk. Storage = "none"
      # keeps systemd-coredump's backtrace handling (so crashes are still
      # diagnosable from the journal) while writing nothing to /var/lib.
      systemd.coredump = {
        enable = true;
        settings.Coredump = {
          Storage = "none";
          ProcessSizeMax = 0;
        };
      };

      # Belt and braces for processes that bypass systemd-coredump.
      security.pam.loginLimits = [
        {
          domain = "*";
          type = "hard";
          item = "core";
          value = "0";
        }
      ];

      # The option above is only worth having if it is checked. Both conditions
      # are evaluated against the final configuration, so a future edit that
      # reintroduces plain swap or a resume device fails the build instead of
      # quietly reopening the leak.
      assertions = lib.optionals cfg.storage.encryptedSwap [
        {
          assertion = lib.all (s: s.randomEncryption.enable) config.swapDevices;
          message = ''
            security.mujo.storage.encryptedSwap is enabled, but these swap devices
            are not encrypted: ${
              lib.concatMapStringsSep ", " (s: s.device)
              (lib.filter (s: !s.randomEncryption.enable) config.swapDevices)
            }
            Plain swap retains whatever pages it held after power-off. Set
            randomEncryption on the swap partition in the host's disko
            configuration, or set security.mujo.storage.encryptedSwap = false to
            accept the risk explicitly.
          '';
        }
        {
          assertion = config.boot.resumeDevice == "";
          message = ''
            security.mujo.storage.encryptedSwap is enabled, but boot.resumeDevice
            is set to "${config.boot.resumeDevice}". Hibernation writes the whole
            of RAM to that device; under a per-boot random key it could not be
            read back anyway. Remove resumeDevice from the disko swap entry.
          '';
        }
      ];
    };
  };
}
