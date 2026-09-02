# Mujo Storage & Persistence Model

This document specifies the storage layout, persistence classification, encrypted container vault architecture, swap leakage prevention, and snapshot discipline in Mujo.

---

## 1. Storage Architecture & Partition Layout

Mujo runs on a partitioned layout managed by Disko without requiring destructive repartitioning to achieve strong confidentiality:

```
GPT Disk Partition Table
├── ESP (/boot)        ── 2 GB FAT32 (EFI System Partition, signed kernels)
├── Swap Partition     ── 16 GB (Ephemeral / Encrypted Swap)
└── LVM Physical Vol   ── btrfs_vg
     └── Btrfs Subvolumes:
          ├── /root    ── (Unmounted / wiped; root is tmpfs)
          ├── /persist ── Persistent host data (zstd:1, noatime)
          │    └── secure/
          │         └── mujo-vault.luks  ── LUKS2 Encrypted Container
          └── /nix     ── Nix Store (zstd:1, noatime)
```

### In-Place LUKS2 Container Vault

```
                    Btrfs Filesystem (/persist)
                                │
                    /persist/secure/mujo-vault.luks
                                │
                     LUKS2 Crypto Boundary (Argon2id KDF + AES-XTS)
                                │
                    ┌───────────▼───────────┐
                    │    Decrypted Vault    │
                    │   (/run/mujo/vault)   │
                    └───────────┬───────────┘
                                │
    ┌───────────────────────────┼───────────────────────────┐
    │                           │                           │
    ▼                           ▼                           ▼
credentials/                ssh/ & gpg/             browser-secrets/
(tokens, API keys)        (private keyrings)       (Vaultwarden, cookies)
```

The vault file `/persist/secure/mujo-vault.luks` is formatted as a LUKS2 volume formatted with Ext4 or Btrfs inside the container. It is unlocked into memory at `/run/mujo/vault` during user login.

---

## 2. Sensitive Data Classification & Inventory

Every path across the system falls into one of three classifications:

| Category | Storage Location | Examples | Protection Strategy |
|---|---|---|---|
| **Persistent + Encrypted** | `/run/mujo/vault/` (stored in LUKS2 container) | `~/.ssh/id_*`, `~/.gnupg/`, API tokens, browser passwords, private documents | AES-256-XTS, Argon2id KDF, strict 0700 permissions, mediated access |
| **Persistent + Non-Sensitive** | `/persist/` (Btrfs subvolume) | `/etc/nixos/`, system preferences, network connection names, package configurations | Standard POSIX DAC + user permissions |
| **Ephemeral** | `tmpfs` (RAM) | `/`, `/tmp`, `/run`, coredumps, application scratch caches | Destroyed on shutdown/reboot |

### Prohibited Leakage Paths
The following locations must never store persistent plaintext secrets:
- `/persist/` outside the `.luks` container
- `/var/log/` and `journald`
- Unencrypted swap partitions
- Crash dump / core dump files
- Btrfs metadata and snapshot logs

---

## 3. Swap & Hibernation Protection

1. **Ephemeral / Encrypted Swap**:
   - Swap space is configured to prevent sensitive memory pages from surviving a reboot.
   - Swap partitions are encrypted with a fresh random key at every boot (`dm-crypt` random key, set via `randomEncryption` on the disko swap entry). This is enforced, not merely recommended: `security.mujo.storage.encryptedSwap` asserts at build time that every entry in `config.swapDevices` is encrypted and that `boot.resumeDevice` is unset, so a future edit that reintroduces plain swap fails the build.
   - Hibernation is therefore unsupported. A suspend-to-disk image cannot be read back under a key that no longer exists.
   - Core dumps are the other route from RAM to disk. `systemd.coredump.settings.Coredump.Storage = "none"` stops new ones, and `/var/lib/systemd/coredump` was removed from the impermanence persistence list — while it was on that list, 94 compressed RAM images (browser, Steam, Discord, IDE) had accumulated on unencrypted storage.
   - Primary memory compression uses in-RAM `zram` (`vm.page-cluster = 0`).

2. **Hibernation Invariant**:
   - Unencrypted hibernation is strictly disabled.
   - Resume devices without full container encryption are rejected to prevent cold-boot disk extraction of decrypted memory dumps.

---

## 4. Btrfs Snapshot Discipline

Using a file-backed LUKS2 container on Btrfs provides a critical security advantage:
- When automated Btrfs snapshots of `/persist` are taken (e.g. via snapper or btrbk), snapshots capture only the **encrypted container file's blocks**.
- Snapshots never capture plaintext secrets.
- Deleting a secret inside the unlocked vault securely frees the sector inside the virtual filesystem without leaving historic plaintext in underlying Btrfs snapshot trees.
