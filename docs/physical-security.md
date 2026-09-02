# Mujo Physical Security & Verified Boot

This document establishes the physical attack protections, UEFI Secure Boot, TPM measurements, bootloader hardening, and offline extraction defenses for Mujo.

---

## 1. Verified Boot Chain

```
               ┌───────────────────────────────┐
               │         UEFI FIRMWARE         │
               │   Firmware Password Protected │
               │     Secure Boot: Custom PK    │
               └───────────────┬───────────────┘
                               │
                        Signed UKI / EFI
                               │
               ┌───────────────▼───────────────┐
               │    BOOTLOADER / LANZABOOTE    │
               │   Bootloader Editor: Locked   │
               │   Kernel CLI Tamper Protected │
               └───────────────┬───────────────┘
                               │
                        TPM 2.0 PCR Measure
                               │
               ┌───────────────▼───────────────┐
               │    SIGNED KERNEL + INITRD     │
               │   Kernel Lockdown: Integrity  │
               │   SMEP / SMAP / KASLR Active  │
               └───────────────┬───────────────┘
                               │
               ┌───────────────▼───────────────┐
               │       NIXOS ROOT (TMPFS)      │
               │   Persistent Mounts (/persist)│
               │   LUKS2 Vault Locked          │
               └───────────────────────────────┘
```

---

## 2. Boot Hardening & Authentication

1. **Secure Boot & Lanzaboote** — *wired up, currently disabled*:
   - `security.mujo.boot.secureBoot` defaults to `false`, so the host boots via GRUB today. Everything below describes what enabling it buys, not what is presently enforced.
   - Once enabled, NixOS generations are signed by Lanzaboote with user-controlled Secure Boot keys (PK, KEK, db), and unsigned external kernels or modified initrds are rejected by firmware.
   - **While it is off, physical access is root access**: GRUB's menu cannot be locked, so an attacker at the keyboard presses `e`, appends `init=/bin/sh`, and gets a root shell without a password. The storage controls still hold — the vault stays encrypted and swap is random-keyed — but the boot chain itself is not a barrier.

2. **Bootloader Configuration Lockout** — *takes effect with Secure Boot*:
   - Kernel command-line editing at the boot prompt is disabled (`editor = false`). This is a systemd-boot setting, so it does nothing while GRUB is the active loader; GRUB has no equivalent.
   - Timeout is minimized (1 second) to prevent opportunistic modification during unattended boots.

3. **Recovery Authentication**:
   - `systemd.enableEmergencyMode = false`: a failed mount reboots rather than dropping to a shell, so there is no emergency console to authenticate against in the first place.
   - `SYSTEMD_SULOGIN_FORCE` must never be set. It is not an authentication switch — it instructs `systemd-sulogin-shell` to open a root shell *without* prompting, and an earlier revision of `nixos/security/boot.nix` set it while believing the opposite. `tests/security/test-kernel-hardening.sh` fails if it reappears.

4. **Firmware Security Guidelines**:
   - UEFI firmware setup password must be enabled to prevent disabling Secure Boot or altering the boot order.
   - Booting from arbitrary external USB media should be disabled in firmware policy.

---

## 2a. Secure Boot Enrolment Runbook

The host moved from GRUB to lanzaboote. GRUB offers no way to lock its menu: anyone at
the keyboard could press `e`, append `init=/bin/sh`, and get root without a password,
which defeats every storage control below it. lanzaboote installs a signed EFI stub
instead, and `boot.loader.systemd-boot.editor = false` removes the command-line prompt.

Run these steps in order. **Do not enable Secure Boot in firmware before step 4** —
enrolling keys while the firmware still trusts only Microsoft's certificates is what
produces an unbootable machine.

1. **Create the signing keys.** They live in `/var/lib/sbctl`, which
   `nixos/security/boot.nix` adds to the persistence list so they survive the root wipe.
   The tooling is installed regardless of the switch below, so this step is safe on its own.

   ```bash
   sudo sbctl create-keys
   ```

2. **Flip the switch and rebuild.** Set `security.mujo.boot.secureBoot = true` (in
   `nixos/overrides/`, or directly on the host config), then rebuild. This is the step that
   replaces GRUB, and lanzaboote signs each generation during activation.

   ```bash
   pkexec nixos-rebuild switch --flake /home/yurii/nixconf#main
   ```

   If `/var/lib/sbctl` is empty the bootloader install step fails and leaves the
   *existing* bootloader in place, so a missing key bundle cannot brick the machine.
   Fix the keys and re-run.

3. **Reboot and confirm the machine still starts** with Secure Boot still *off*. At this
   point the boot chain is signed but nothing is enforcing the signatures yet. Verify:

   ```bash
   mujo-secureboot status     # expect: Secure Boot State: DISABLED (Setup / Inactive)
   sudo sbctl verify          # every file under /boot should report as signed
   ```

4. **Put the firmware into Setup Mode** (clear the platform key; the exact menu name is
   vendor-specific — often "Erase all Secure Boot Settings" or "Clear Keys"), then enrol:

   ```bash
   sudo sbctl enroll-keys --microsoft
   ```

   `--microsoft` retains Microsoft's certificates alongside ours. Drop it only if you are
   certain no option ROM on this machine — GPU firmware in particular — needs them; without
   them an AMD GPU that ships a Microsoft-signed option ROM may leave you with no display.

5. **Enable Secure Boot in firmware, set a firmware setup password, and disable booting
   from external media.** Secure Boot is worth little if an attacker can enter setup and
   switch it off. Then confirm enforcement:

   ```bash
   mujo-secureboot status     # expect: Secure Boot State: ENABLED (Enforcing)
   ```

**Rollback.** If the machine will not boot after step 5, enter firmware setup, disable
Secure Boot, and boot normally — the signed stub loads fine without enforcement. The
generation menu still lists previous generations, so a bad generation is recoverable the
usual way. To go back to GRUB entirely, set `security.mujo.boot.secureBoot = false` and
rebuild from a working generation or a NixOS installer chroot.

---

## 3. Physical Extraction & "Stolen Drive" Attack Defense

### Attack Scenario
An adversary physically removes the Mujo NVMe/SSD drive and connects it to an external analysis workstation or forensic dock.

### Defense Matrix

| Target Partition / Subvolume | Data Observable to Attacker | Secret Protection Status |
|---|---|---|
| **ESP Partition (`/boot`)** | Public signed kernel, initrd, EFI binaries | **Protected**: No confidential information stored. |
| **Btrfs `/nix` Subvolume** | Public Nix store packages and derivations | **Protected**: Public binaries only. |
| **Btrfs `/persist` Subvolume** | Declarative system configs, non-sensitive state | **Conditionally protected**: holds no secrets *provided* the inventory is clean. `mujo-inventory` and `tests/storage/test-vault-isolation.sh` enforce this; both currently report the user's `~/.ssh` private key as an outstanding migration. |
| **`/persist/secure/mujo-vault.luks`** | High-entropy ciphertext blob only | **Protected (LUKS2 + Argon2id)**: Requires user password to derive master encryption key. |
| **Swap Partition** | Ephemeral random-keyed ciphertext | **Protected**: re-keyed at every boot (`randomEncryption` in `nixos/hosts/main/disko.nix`), so pages are unrecoverable after power-off. Hibernation is unavailable as a direct consequence — there is no stable key to resume under. |
| **Root Filesystem (`/`)** | Non-existent (tmpfs in RAM) | **Protected**: Destroyed on power loss. |

---

## 4. "Alternate OS Installation" Attack Defense

### Attack Scenario
An attacker extracts the SSD, replaces or modifies the EFI bootloader or creates a malicious OS partition, and reinstalls the drive.

### Defense Outcome
1. **Secure Boot Enforces Signatures**: Firmware rejects the modified EFI executable.
2. **TPM 2.0 PCR Validation**: Alterations to the partition table or bootloader fail PCR measurements, refusing automatic key release or flagging boot tampering.
3. **No Vault Access**: Even if an unauthorized OS boots successfully, the LUKS2 container vault cannot be decrypted without the user's master passphrase.
