# Mujo Performance Budget & Engineering Standards

Security must not degrade the system to the point of user frustration or workflow friction. This document specifies the hard performance limits, optimization strategies, and benchmarking criteria for Mujo.

---

## 1. Mujo Performance Budget Matrix

All security subsystems, hypervisor layers, and sandboxing rules must operate within the following performance envelope compared to a non-hardened baseline:

```
                  MUJO PERFORMANCE BUDGET ENVELOPE

Workload Domain          Allowed Overhead       Acceptance Threshold
──────────────────────────────────────────────────────────────────
Normal Desktop UI            < 5%              PASS (Imperceptible)
Native Applications          < 5%              PASS (Instant response)
Gaming Workloads             < 5%              PASS (Native FPS target)
GPU Workloads                < 5%              PASS (Hardware accelerated)
Storage / NVMe I/O           < 10%             PASS (High throughput)
Build / Nix Compiles         < 15%             PASS (Bounded build cost)
──────────────────────────────────────────────────────────────────
HARD LIMIT: Workload regression > 15% across any domain = FAIL
```

---

## 2. Architectural Optimizations

To achieve strong security without exceeding the budget, Mujo employs specific architectural optimizations:

### 2.1 MicroVM Acceleration
- **KVM Direct Execution**: Near-zero virtualization overhead for CPU instructions.
- **Hardware Passthrough**: Direct instruction extensions (`invtsc`, `clflushopt`, `fsrm`) forwarded to guest environments.
- **VirtIO Devices**: VirtIO-GPU, VirtIO-FS, and VirtIO-Net for high-speed paravirtualized I/O.
- **Pre-warmed VM Pools**: Background worker VMs pre-initialized in RAM to provide sub-second application launch times.

### 2.2 Host & Kernel Efficiency
- **No Heavy Continuous Scanners**: Avoid signature-based real-time file scanners; enforce security through capability boundaries and isolated namespaces instead.
- **Selective Sysctl Hardening**: Mitigations are targeted to high-risk attack surfaces (BPF, ptrace, user namespaces) without penalizing regular syscall paths.
- **ZRAM + High Efficiency Cache**: Slab/inode caches reclaimed smoothly with `vm.vfs_cache_pressure = 150` and ZRAM page clustering.

### 2.3 Graduated Native Sandboxing
- Applications that pass 72 hours of clean quarantine observation graduate from MicroVMs to lightweight native systemd/seccomp sandboxes, reducing memory and CPU overhead to <1%.

---

## 3. Benchmarking & Regression Verification

Before introducing new security policies or kernel mitigations, automated benchmarks must be recorded:
1. **Boot Time**: Measured via `systemd-analyze` and `systemd-analyze blame` (target: < 6s to desktop).
2. **App Launch Latency**: Measured for cold/warm launches of Firefox, Terminal, and Quickshell.
3. **Graphics & Compute**: Measured via `glxgears` / `vkmark` / compute benchmarks.
4. **I/O Throughput**: Measured via `fio` random read/write tests on `/persist` and `/run`.

---

## 4. Measured Results

`tests/performance/test-performance-budget.sh` takes every measurement as a
**pair within a single run** — the same work, natively and then behind each
boundary — because this machine has no non-hardened twin to compare against.
Numbers below are from an i9-14900K and were stable across repeated runs.

| Boundary | Workload | Measured | Budget | Verdict |
|---|---|---|---|---|
| Native sandbox | 10×128MiB SHA-256 | +2% to +4% | <5% | **meets** |
| Native sandbox | process launch | +10ms | <250ms | **meets** |
| Quarantine VM | 10×128MiB SHA-256 | −4% to −5% | <15% | **meets** |
| Quarantine VM | warm launch | ~100ms | <3s | **meets** |

The quarantine guest runs sustained CPU work at parity with the host, which is
what §2.1 predicts: KVM executes guest instructions directly, and `sha_ni` plus
the full CPU model pass through to the guest.

### The real cost is per-launch, not per-cycle

The number that actually matters for quarantine is the **~100ms warm launch**,
and it is a fixed cost rather than a percentage. It is invisible for an
application the user keeps open, and dominant for anything short-lived: a
command taking 50ms natively takes ~150ms in the domain. Phase 37's pre-warmed
pools would address it; a single shared domain already avoids the multi-second
cold boot.

### Graphics, which the table above does not cover

CPU was never the quarantine domain's problem — the table says so. What made it
feel slow was that every window was rasterised by llvmpipe on the guest's vCPUs
and then memcpy'd across vsock. Three things changed, none of them measured yet
(no number is claimed here until `tests/performance/` covers GL):

- `apps.microvm.gpu` defaults to `"native"`: a `virtio-gpu-gl` with
  `drm_native_context=on`, so the guest's mesa speaks the amdgpu UAPI straight
  through to the host driver rather than having its GL replayed. `"virgl"` is
  the translated middle setting and `"none"` is llvmpipe. This is the change
  that matters for Electron and Steam, and the one with a security cost — see
  `docs/application-trust.md` §6.
- `apps.microvm.cores` went 6 → 12 and `memoryMb` 6144 → 8192. Both matter most
  in the *fallback* case: llvmpipe scales with vCPU count, so a domain with
  `gpu = "none"` is still roughly twice the rasteriser it was.
- The guest no longer runs speculative-execution mitigations (`mitigations=off`
  in its kernel params) and no longer pays for the stripped `nixosTestRunner`
  qemu, which had no EGL at all.

### Two methodology traps, both hit while writing this suite

Recorded because both produced confident and entirely fictional numbers.

1. **A +326% sandbox regression that did not exist.** The suite resolved
   `sha256sum` by name on both sides, and `mujo-sandbox-run` leaked the
   launcher's `PATH` into the sandbox — so the host measured `coreutils-full`
   (OpenSSL, SHA-NI accelerated) while the sandbox measured plain `coreutils`.
   Two different binaries, a 4x gap. Fixed at both ends: the sandbox now sets
   `PATH` explicitly, and the suite pins one absolute binary used everywhere.

2. **A +59% quarantine regression that did not exist.** With only five passes,
   the domain's ~100ms launch cost was a third of the measurement and the ratio
   read as virtualisation overhead. It even survived a plausible-sounding
   explanation — hybrid-CPU E-core scheduling — before ten passes showed the
   guest had been at parity all along. A fixed cost inside a ratio will always
   masquerade as a rate.

The rule both point at: **measure long enough that fixed costs amortise, and
pin every variable that is not the boundary under test.**
