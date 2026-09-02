{pkgs, ...}: {
  flake.nixosModules.security-boot = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.security.mujo;

    # Secure Boot & TPM management tool
    mujoSecureBootCli = pkgs.writeShellApplication {
      name = "mujo-secureboot";
      runtimeInputs = with pkgs; [sbctl tpm2-tools coreutils util-linux efibootmgr];
      text = ''
        set -euo pipefail

        KEY_DIR="/var/lib/sbctl"

        usage() {
          echo "Usage: mujo-secureboot {status|setup-keys|enroll|verify-tpm}"
          echo ""
          echo "Commands:"
          echo "  status       - Show UEFI Secure Boot and TPM 2.0 status"
          echo "  setup-keys   - Generate custom Mujo Secure Boot PK/KEK/db keys"
          echo "  enroll       - Enroll generated keys into UEFI firmware (Setup Mode)"
          echo "  verify       - Check every file in the ESP is signed by our keys"
          echo "  verify-tpm   - Inspect TPM 2.0 PCR measurements"
          exit 1
        }

        cmd_status() {
          echo "=== Mujo Boot Integrity Status ==="
          echo "--- Secure Boot (sbctl) ---"
          if command -v sbctl >/dev/null 2>&1; then
            sbctl status || true
          else
            echo "sbctl tool not available"
          fi

          echo ""
          echo "--- EFI Boot Variables ---"
          if [ -d /sys/firmware/efi ]; then
            echo "UEFI Boot: Active (EFI runtime available)"
            if [ -f /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c ]; then
              local sb
              sb=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c | awk '{print $NF}')
              if [ "$sb" = "1" ]; then
                echo "Secure Boot State: ENABLED (Enforcing)"
              else
                echo "Secure Boot State: DISABLED (Setup / Inactive)"
              fi
            fi
          else
            echo "UEFI Boot: Not detected (Legacy BIOS)"
          fi

          echo ""
          echo "--- TPM 2.0 Interface ---"
          if [ -e /dev/tpmrm0 ] || [ -e /dev/tpm0 ]; then
            echo "TPM 2.0 Device: Present (/dev/tpmrm0)"
            if command -v tpm2_pcrread >/dev/null 2>&1; then
              echo "PCR[0..7] measurement state:"
              tpm2_pcrread sha256:0,1,2,7 || true
            fi
          else
            echo "TPM 2.0 Device: Absent or driver not loaded"
          fi
        }

        cmd_setup_keys() {
          # $KEY_DIR is sbctl's own default bundle location, which is also what
          # boot.lanzaboote.pkiBundle points at, so create-keys needs no path
          # argument. It is on the persistence list in nixos/security/boot.nix;
          # losing it means re-enrolling in firmware, not just rebuilding.
          echo "Creating custom Secure Boot keys in $KEY_DIR..."
          sbctl create-keys
          chmod 700 "$KEY_DIR"
          echo ""
          echo "Keys created. Next: rebuild so lanzaboote signs this generation,"
          echo "reboot to confirm the machine still starts, then put the firmware"
          echo "into Setup Mode and run 'mujo-secureboot enroll'."
          echo "Full runbook: docs/physical-security.md section 2a."
        }

        cmd_enroll() {
          # --microsoft keeps Microsoft's certificates alongside ours. Dropping it
          # bricks the display on any machine whose GPU ships a Microsoft-signed
          # option ROM, which is most of them.
          echo "Enrolling keys into UEFI firmware (firmware must be in Setup Mode)..."
          sbctl enroll-keys --microsoft
          echo ""
          echo "Enrolled. Enable Secure Boot in firmware, set a firmware setup"
          echo "password, then run 'mujo-secureboot status' to confirm enforcement."
        }

        cmd_verify_tpm() {
          echo "Reading TPM 2.0 PCR measurements..."
          tpm2_pcrread
        }

        case "''${1:-}" in
          status)     cmd_status ;;
          verify)     sbctl verify ;;
          setup-keys) cmd_setup_keys ;;
          enroll)     cmd_enroll ;;
          verify-tpm) cmd_verify_tpm ;;
          *)          usage ;;
        esac
      '';
    };
  in {
    options.security.mujo.boot = {
      secureBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Boot the machine through lanzaboote with our own Secure Boot keys
          instead of GRUB. Off by default: it is the only switch in this repo
          that replaces the bootloader, so enabling it without first working
          through docs/physical-security.md section 2a can leave the machine
          unable to start. The tooling below (mujo-secureboot, sbctl, key
          persistence) is installed either way, so the keys can be created and
          verified before anything is switched over.
        '';
      };
    };

    config = lib.mkIf (cfg.enable && cfg.boot.enable) {
      environment.systemPackages = [
        mujoSecureBootCli
        pkgs.sbctl
        pkgs.tpm2-tools
        pkgs.efibootmgr
      ];

      # Removes the interactive kernel command-line prompt, so nobody at the
      # keyboard can append init=/bin/sh. Only has an effect once secureBoot puts
      # the systemd-boot-compatible loader in place; GRUB offers no equivalent.
      boot.loader.systemd-boot.editor = lib.mkDefault false;

      # Recovery must not be a way around the root password.
      #
      # This module used to set SYSTEMD_SULOGIN_FORCE=1 in the belief that it
      # enforced authentication. It does the opposite: it tells
      # systemd-sulogin-shell to hand out a root shell *without* asking, which is
      # the documented escape hatch for machines whose root account is locked.
      # Not setting it is the whole fix, and sulogin then prompts as intended.
      #
      # Emergency mode itself stays enabled. Turning it off converts any failed
      # mount into an immediate reboot with no console to diagnose from, which
      # trades a recovery path for no security: without SULOGIN_FORCE the
      # emergency console already demands the root password.
      systemd.enableEmergencyMode = lib.mkDefault true;

      # sbctl's PKI bundle holds the Secure Boot signing keys. lanzaboote reads it
      # at activation time to sign every generation, so it has to survive the
      # impermanence root wipe -- otherwise each rebuild would need fresh keys
      # enrolled in firmware.
      persistence.directories = [
        {
          directory = "/var/lib/sbctl";
          mode = "0700";
        }
      ];
    };
  };
}
