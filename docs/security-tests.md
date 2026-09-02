# Mujo Security Test Specification & Red-Team Assertions

This document defines the automated test suite, red-team violation tests, and physical extraction verification procedures for Mujo.

---

## 1. Automated Security Test Matrix

The test suite validates that system boundaries cannot be breached under adverse conditions:

| Test Identifier | Category | Action / Attack Attempt | Expected Result |
|---|---|---|---|
| `SEC-001` | **Kernel Hardening** | Unprivileged process attempts `ptrace` attach on peer process or system service. | **DENIED** (`EPERM` / `yama.ptrace_scope`) |
| `SEC-002` | **Kernel BPF** | Unprivileged process attempts to load eBPF probe or socket filter. | **DENIED** (`unprivileged_bpf_disabled = 1`) |
| `SEC-003` | **Storage Isolation** | Scan persistent storage (`/persist`, `/nix`) for known plaintext secret canary tokens. | **ZERO CANARIES FOUND** |
| `SEC-004` | **Vault Permissions** | Unprivileged or sandboxed user attempts to read `/run/mujo/vault` or `/persist/secure/mujo-vault.luks`. | **DENIED** (Strict 0700 file/mount permissions) |
| `SEC-005` | **MicroVM Sandbox** | Guest process attempts to access host `/home`, `/persist`, or host D-Bus socket. | **DENIED** (No shared 9p/virtiofs host mounts) |
| `SEC-006` | **Swap Leakage** | Memory containing secret tokens flushed to swap; swap inspected offline. | **NO PLAINTEXT FOUND** (Swap ephemeral / encrypted) |
| `SEC-007` | **Crash Dumps** | Process containing sensitive key terminates abnormally via SIGSEGV. | **NO CORE DUMP WRITTEN TO DISK** |
| `SEC-008` | **Network Spoofing** | Inbound spoofed packet or ICMP redirect sent to host interface. | **DROPPED** (`rp_filter = 1`, `accept_redirects = 0`) |
| `SEC-009` | **Update Trust Reset** | Application binary hash modified / updated in Nix store. | **RESETS TO QUARANTINE** (0/72h observation counter) |
| `SEC-010` | **Native Sandbox Containment** | Graduated application in the native sandbox attempts to reach the vault, `/persist`, or the user's SSH key. | **DENIED** (bubblewrap namespaces; nothing bound in) |
| `SEC-011` | **Recovery Lockout** | Emergency boot target invoked without password. | **PASSWORD PROMPT ENFORCED** (`sulogin`) |

---

## 2. Physical Extraction Test Procedure (Offline Storage Analysis)

This test procedure verifies that removing the physical NVMe drive yields no sensitive user data.

```
                    PHYSICAL EXTRACTION VERIFICATION FLOW

  1. Boot Mujo & Authenticate
             │
  2. Unlock LUKS2 Vault & Write Canary Token ("SECRET_CANARY_HEX_987654321")
             │
  3. Perform Normal Operations & Clean Shutdown
             │
  4. Physically Mount SSD on External Forensic Analysis System
             │
  5. Search Entire Storage Medium for Canary Token:
     • Partition Table & ESP
     • Btrfs /root, /nix, /persist
     • Swap Partition
     • Btrfs Snapshot Blocks & Free Space
             │
  6. Assert:
     ✓ 0 instances of Canary Token in persistent unencrypted blocks
     ✓ Container file /persist/secure/mujo-vault.luks is valid LUKS2 header
     ✓ Root is empty / wiped
```

---

## 3. Automated Test Directory Layout

The test suite in `tests/` mirrors this specification:

```
tests/
├── run-all-tests.sh               # Consolidated test harness
├── security/
│   └── test-kernel-hardening.sh   # Validates sysctls, ptrace, and BPF protections
├── storage/
│   ├── test-vault-isolation.sh    # Verifies LUKS2 container boundaries & tmpfs root
│   └── test-swap-leakage.sh       # Verifies swap and coredump leak policies
├── network/
│   └── test-firewall-rules.sh     # Validates firewall and network stack hardening
├── sandbox/
│   └── test-sandbox-isolation.sh  # Verifies sandbox boundary containment
└── physical/
    └── test-physical-extraction.sh# Offline storage analysis simulator
```

---

## 4. Suite Layout

`bash tests/run-all-tests.sh` runs everything. Each file probes the **running
system**, never the flake, so the suite is red until the configuration has been
applied — a check that cannot fail is not a check.

| Path | ID | What it attacks |
|---|---|---|
| `tests/security/test-kernel-hardening.sh` | SEC-001/002 | ptrace scope, BPF, kernel surface sysctls |
| `tests/storage/test-vault-isolation.sh` | SEC-004 | vault mount and container permissions |
| `tests/storage/test-swap-leakage.sh` | SEC-006 | secrets reaching swap |
| `tests/network/test-firewall-rules.sh` | SEC-008 | inbound and spoofing policy |
| `tests/sandbox/test-sandbox-isolation.sh` | SEC-010 | native sandbox containment |
| `tests/microvm/test-quarantine-boundary.sh` | SEC-005 | quarantine is a VM, not a namespace |
| `tests/trust/test-trust-engine.sh` | SEC-009 | the graduation policy's fourteen transitions |
| `tests/physical/test-physical-extraction.sh` | SEC-003 | plaintext on persistent storage |
| `tests/recovery/test-recovery-bypass.sh` | SEC-011 | unauthenticated recovery, boot tampering, hibernation |
| `tests/redteam/test-boundary-violations.sh` | — | the full escape matrix, every expected result DENIED |
| `tests/performance/test-performance-budget.sh` | — | isolation overhead against the budget |

### On the performance suite

The budget in `docs/performance-budget.md` is written as overhead "compared to a
non-hardened baseline", and this machine has no non-hardened twin. Rather than
invent one, every measurement is **paired within a single run**: the same work
natively, then behind each isolation boundary. That ratio is what the isolation
costs, and it is what the budget is trying to bound.

Host-wide hardening — sysctls, kernel mitigations — is not measurable this way,
and the suite does not claim to measure it.

### On the red-team suite

Its checks are attacks, so the polarity is inverted: a command that *succeeds*
is a failure. A boundary that cannot be tested reports SKIP; a boundary that
was crossed never does.
