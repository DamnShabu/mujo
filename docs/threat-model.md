# Mujo Threat Model & Security Invariants

This document establishes the adversary profiles, security boundaries, fundamental invariants, and non-goals of the Mujo operating system.

---

## 1. Adversary Profiles

| Adversary Level | Capabilities | Expected Defense |
|---|---|---|
| **A1: Casual Physical Attacker** | Temporary physical access to the device while powered off or locked (e.g., opportunistic theft, evil maid in hotel room). Can extract SSD or boot USB media. | **Full Defense**: Secure Boot + TPM verification blocks unauthorized boot chains. Sensitive data encrypted in LUKS2 container vault; swap wiped/encrypted; root is tmpfs. |
| **A2: Malicious / Untrusted Application** | Running malicious or compromised third-party application code (e.g., malware from web, compromised dependency). | **Full Defense**: Runs in disposable MicroVM (Quarantine) with ephemeral root/home and no access to vault, host IPC, or host credentials. |
| **A3: Graduated Compromised App** | Application compromised after graduating to native sandbox. | **Layered Containment**: Native process sandboxed via systemd cgroups, namespaces, seccomp, capability restrictions, and strict filesystem allowlists. No direct access to vault files or other applications. |
| **A4: Malicious Supply-Chain / Update** | Malicious payload introduced in application update. | **Detection & Isolation**: Update changes executable hash/identity, immediately resetting trust state back to Quarantine (MicroVM) for 72-hour re-evaluation. Rollback available on behavioral alert. |
| **A5: Kernel / Ring-0 Exploitation (Unlocked)** | Complete host kernel compromise while the vault is active and unlocked in RAM. | **Non-Goal / Boundary**: Physical and memory isolation on commodity hardware cannot prevent full Ring 0 from accessing unlocked RAM keys. Mitigations (KASLR, SMAP, SMEP, Lockdown, BPF lockdown) maximize exploitation difficulty, and secrets exist in RAM for the absolute minimal window. |

---

## 2. Fundamental Security Invariants

1. **Storage Invariant (No Plaintext Secrets on Persistent Media)**:
   Sensitive plaintext (SSH keys, GPG keys, tokens, browser passwords, private documents) must **never** intentionally reside on unencrypted persistent storage (`/persist`, unencrypted swap, or crash dumps). All persistent secrets reside strictly inside the LUKS2 container vault (`/persist/secure/mujo-vault.luks`).

2. **Offline Extraction Invariant**:
   Removing the physical storage drive and mounting it on an external system must reveal **zero** plaintext credentials, personal tokens, or private document contents.

3. **Boot Integrity Invariant**:
   Any modification to the boot chain (UEFI firmware, bootloader, kernel, initrd) must be detected prior to execution via UEFI Secure Boot and TPM measurements, preventing bootloader hijacking or unauthorized OS substitution.

4. **Ephemeral Host Root Invariant**:
   The root filesystem `/` is a RAM-backed `tmpfs`. Unpersisted system state, temporary files, and runtime residues are destroyed on every reboot.

5. **Quarantine Invariant**:
   Newly installed or updated applications execute strictly inside an isolated disposable MicroVM with a read-only store projection, ephemeral scratch disks, and zero visibility into the host `/persist` or vault.

6. **Graduation Invariant**:
   Graduation from MicroVM to native execution is earned only after 72 hours of observation and policy validation, and graduated applications remain permanently sandboxed under principle of least privilege.

7. **Atomic Rollback Invariant**:
   If an application update exhibits anomalous security events in quarantine, the update is revoked and the previous known-good version is preserved and accessible.

8. **Crash Dump & Memory Invariant**:
   Process memory dumps and core dumps for sensitive processes are disabled or restricted to prevent RAM secrets from landing in disk caches.

---

## 3. Trust Boundaries & Information Flow

```
                           ┌───────────────────────────┐
                           │      PHYSICAL BOUNDARY    │
                           │  UEFI + TPM 2.0 + Storage │
                           └─────────────┬─────────────┘
                                         │
                                         ▼
                           ┌───────────────────────────┐
                           │     HOST HARDENING        │
                           │  Kernel / Namespaces / PAM│
                           └─────────────┬─────────────┘
                                         │
        ┌────────────────────────────────┼────────────────────────────────┐
        │                                │                                │
        ▼                                ▼                                ▼
┌───────────────┐              ┌──────────────────┐              ┌─────────────────┐
│ NATIVE SANDBOX│              │  ENCRYPTED VAULT │              │    MICROVM      │
│  (Graduated)  │              │ (LUKS2 Container)│              │  (Quarantine)   │
│               │              │                  │              │                 │
│ Systemd cgroup│              │ /run/mujo/vault  │              │ Ephemeral VM    │
│ Seccomp       │◄────Broker───┤ Strict 0700      │              │ Minimal VirtIO  │
│ Landlock/MAC  │              │ Plaintext denied │              │ Zero Host State │
└───────┬───────┘              └──────────────────┘              └────────┬────────┘
        │                                                                 │
        └────────────────────────────────┬────────────────────────────────┘
                                         ▼
                           ┌───────────────────────────┐
                           │   MUJO DESKTOP INTEGRATION│
                           │       Niri / Wayland      │
                           └───────────────────────────┘
```

---

## 4. Explicit Non-Goals & Architectural Tradeoffs

- **No Repartitioning Requirement**: Full-disk encryption (FDE) requires repartitioning the disk. To enable seamless adoption on existing systems without data loss, Mujo utilizes a file-backed LUKS2 container vault inside `/persist/secure/` combined with a tmpfs root, encrypted/ephemeral swap, and Secure Boot. The accepted tradeoff is that public Nix store metadata and non-sensitive system configurations remain observable on offline storage, while all confidential user data is encrypted.
- **Hardware-Enforced Ring-0 Defense**: On commodity x86_64 hardware, an active kernel exploit while the LUKS vault is mounted in RAM cannot be prevented from inspecting physical memory. The goal is compromise containment before kernel-level escalation occurs.
