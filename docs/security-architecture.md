# Mujo Security Architecture

Mujo turns a declarative NixOS desktop into a multi-layered security architecture with cooperating subsystems. This document details the system design, components, and information flow.

---

## 1. System Architecture Overview

```
                         ┌─────────────────────────────┐
                         │       PHYSICAL MACHINE      │
                         │    UEFI 2.7+ with TPM 2.0   │
                         │     Secure Boot Enabled     │
                         └──────────────┬──────────────┘
                                        │
                                 verified boot
                                        │
                         ┌──────────────▼──────────────┐
                         │          MUJO HOST          │
                         │                             │
                         │  • Ephemeral tmpfs root     │
                         │  • Hardened Linux Kernel    │
                         │  • Strict Systemd Sandboxes │
                         │  • Hardened Stateful F/W    │
                         └──────────────┬──────────────┘
                                        │
         ┌──────────────────────────────┼──────────────────────────────┐
         │                              │                              │
         ▼                              ▼                              ▼
┌───────────────────┐          ┌───────────────────┐          ┌───────────────────┐
│ NATIVE SANDBOX    │          │  ENCRYPTED VAULT  │          │    MICROVM        │
│ (Graduated Apps)  │          │  (Sensitive Data) │          │ (Quarantine Apps) │
│                   │          │                   │          │                   │
│ • Namespaces      │          │ • LUKS2 Container │          │ • KVM Hypervisor  │
│ • Seccomp filters │          │ • Decrypted in RAM│          │ • Ephemeral root  │
│ • Strict cgroups  │          │ • 0700 permission │          │ • Read-only store │
│ • Restrict fs/dev │          │ • Secret broker   │          │ • No host access  │
└────────┬──────────┘          └────────┬──────────┘          └────────┬──────────┘
         │                              │                              │
         └──────────────────────────────┼──────────────────────────────┘
                                        │
                                 Mujo Broker / IPC
                                        │
                         ┌──────────────▼──────────────┐
                         │     DESKTOP INTEGRATION     │
                         │        Niri / Wayland       │
                         │    XDG Desktop Portals      │
                         └─────────────────────────────┘
```

---

## 2. Core Subsystems

### 2.1 Boot Chain & Host Integrity
- **Verified Boot**: Bootloader entries and kernel artifacts are verified via Secure Boot.
- **TPM Measurements**: PCR measurements ensure tamper detection during boot.
- **Ephemeral Host Root**: Root filesystem is mounted on `tmpfs` (`size=25%`). System files and state vanish on reboot, wiping untracked modifications.
- **Impermanence**: Only explicitly declared paths are persisted to `/persist` via bind mounts.

### 2.2 Storage & Vault Subsystem
- **No-Repartitioning LUKS2 Container**: Instead of requiring a destructive disk reformat, sensitive data is stored inside a LUKS2 encrypted container file located at `/persist/secure/mujo-vault.luks`.
- **Decrypted Mountpoint**: Mounted dynamically at `/run/mujo/vault` with strict `0700` user permissions.
- **Vault Hierarchy**:
  ```
  /run/mujo/vault/
  ├── credentials/          # API tokens, account secrets
  ├── ssh/                  # Private keys (~/.ssh/)
  ├── gpg/                  # GPG keyrings (~/.gnupg/)
  ├── browser-secrets/      # Vaultwarden, saved logins, cookies
  ├── personal/             # Private documents & archives
  └── application-secrets/  # App-specific sensitive state
  ```
- **Information Flow Boundary**: Applications do not traverse the vault directory directly; access is gated by the Mujo Credential Broker.

### 2.3 Application Runtime & Progressive Trust
Applications exist in one of four states managed by `mujo-trustd`:

```
   [ Installation / Update ]
               │
               ▼
        ┌──────────────┐
        │  QUARANTINE  │ ──( Runs inside MicroVM with ephemeral root )
        └──────┬───────┘
               │
          72h Observation + Behavioral Event Monitoring
               │
               ▼
        ┌──────────────┐
        │  OBSERVING   │ ──( Policy check & provenance verification )
        └──────┬───────┘
               │
       Passed Validation
               │
               ▼
        ┌──────────────┐
        │  GRADUATED   │ ──( Promoted to native process with tight sandboxing )
        └──────────────┘
               │
      [ Suspicious Event ] ──► [ REVOKED / ROLLBACK ]
```

1. **Quarantine Domain (MicroVM)**:
   - Built on KVM and virtio devices.
   - Minimal guest kernel with read-only Nix store sharing.
   - Ephemeral guest filesystem (`tmpfs`); no access to host `/persist` or `/run/mujo/vault`.
   - Forwarded Wayland sockets and pulse/pipewire audio for seamless UI.

2. **Graduated Domain (Native Sandbox)**:
   - Evaluated applications run natively on host for performance.
   - Constrained by systemd service sandboxing (`ProtectSystem=strict`, `ProtectHome=tmpfs`, `PrivateDevices=true`, `NoNewPrivileges=true`, `MemoryDenyWriteExecute=true`, strict seccomp system-call filter).

3. **Automatic Re-Quarantine on Update**:
   - Nix store derivation changes trigger a new identity calculation.
   - Updated package immediately drops back to Quarantine domain until re-evaluated.

### 2.4 Mujo Desktop Broker
- Mediates system requests (file picking, notifications, camera/microphone, clipboard) between untrusted guest environments and the host compositor (Niri).
- Employs standard XDG Desktop Portals (`xdg-desktop-portal-gtk`, `xdg-desktop-portal-gnome`).
- Mediates camera/mic hardware through portal permission prompts rather than raw `/dev/video*` binding.

---

## 3. User Experience (Zero Overhead UX)

To the user, security mechanisms are transparent:
1. **Power On** → System boots securely.
2. **Login** → Single password unlocks the user session and the LUKS2 vault.
3. **Application Launch** → Whether running inside a MicroVM or as a graduated native process, windows integrate seamlessly into Niri workspaces.
4. **Updates** → Atomic updates run without interrupting workflow; security center only notifies if a behavioral violation occurs.
