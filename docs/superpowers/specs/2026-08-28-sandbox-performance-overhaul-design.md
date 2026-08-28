# VM / Sandbox System — Full Performance, Stability & Architecture Overhaul

## 1. Overview & Goals

The mujō sandbox (`nixos/sandbox/`) provides a disposable, virgl-accelerated graphical NixOS VM with an embedded MCP stdio server. It enables AI agents to inspect and interact with the Wayland/Niri desktop and Quickshell environment without touching the host session or rebuilding NixOS.

### Objectives
1. **≤ 10% Virtualization Overhead Target**: Eliminate unnecessary kernel, QEMU, 9p filesystem, and IPC serialization delays.
2. **Instant UI Reload & Screenshot Pipeline**: Reduce screenshot round-trip latency from ~250ms to <40ms by eliminating intermediate file copies and redundant root backdoor serial commands.
3. **9p I/O Acceleration**: Accelerate read-only repository filesystem access by migrating from synchronous `cache=mmap` to metadata-cached `cache=loose`.
4. **Fast User Command Execution**: Replace heavy PAM `su -l` logins with direct `runuser` execution and cached display variables.
5. **Zero-Lag Input Injection**: Eliminate artificial `sleep` delays in QMP input events by batching absolute coordinate movements and button clicks into atomic transactions.
6. **Quickshell Motion & Render Optimization**: Prevent runaway 60fps property writes on invisible items and optimize ambient phase oscillators.
7. **Fast Failure Diagnostics**: Instantly detect QML syntax errors and service crashes during reloads without waiting for arbitrary timeouts.

---

## 2. Architecture & Subsystems

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Host Environment (Agent / Editor / CLI)                                  │
│                                                                          │
│  [MCP Client] <──(stdio JSON-RPC)──> [mcp.py Driver Engine]              │
│                                              │                           │
│                                   ┌──────────┴──────────┐                │
│                                   ▼                     ▼                │
│                            [QMP Socket]        [9p Shared Exchange]      │
│                            (input / ctrl)      (/tmp/shared: shot, etc)  │
└───────────────────────────────────┬─────────────────────┬────────────────┘
                                    │                     │
┌───────────────────────────────────┼─────────────────────┼────────────────┐
│ QEMU Guest VM (KVM + VirtIO)      ▼                     ▼                │
│                                                                          │
│  - Linux Kernel (mitigations=off, tsc=reliable, nowatchdog, no-hpet)     │
│  - 9p Mount (/mnt/nixconf: cache=loose, ro, msize=1M)                   │
│  - VirtIO-GPU (virgl / egl-headless GLES acceleration)                   │
│  - Niri Wayland Compositor                                               │
│  - Quickshell Desktop (qs-bar.service)                                   │
│    ├── Optimized Anim.qml (gated oscillators)                            │
│    └── Direct /tmp/shared/qs_ready readiness signal                      │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Component Improvements

### 3.1 Kernel & QEMU Virtualization (`nixos/sandbox/sandbox.nix`)
* **Kernel Parameters**:
  * `mitigations=off`: Disable CPU speculative execution mitigations inside isolated throwaway guest VM.
  * `nowatchdog`, `audit=0`, `nomce`: Suppress kernel audit overhead and hardware watchdogs.
  * `tsc=reliable`, `nohpet`: Use high-speed TSC clocksource without timer drift checks.
  * `elevator=none`: Bypass I/O scheduler overhead for virtual block and virtio devices.
  * `quiet`, `rd.udev.log_level=3`, `systemd.show_status=auto`: Eliminate serial console blocking during boot.
* **QEMU Configuration**:
  * Enable KVM kernel irqchip: `-machine q35,accel=kvm,kernel-irqchip=on`.
  * Timer optimization: `-no-hpet -global kvm-pit.lost_tick_policy=discard`.
  * Hardware CPU passthrough: `-cpu host,migratable=off,+invtsc,+tsc-deadline,+clflushopt,+fsrm`.
  * 9p Mount Optimization: Change `/mnt/nixconf` filesystem options to `cache=loose` and `posixacl=0`. Since the mount is strictly read-only, `cache=loose` caches inodes, directory entries, and page cache without making roundtrip 9p metadata calls to the host for every file stat.

### 3.2 MCP Driver & IPC Optimization (`nixos/sandbox/mcp.py`)
* **Single-Hop Direct Screenshots**:
  * `grim /tmp/shared/shot.png` writes directly to the 9p shared exchange directory mounted between host and guest.
  * Completely eliminates the secondary backdoor shell command `run("cp ...")` and intermediate tmpfs write.
* **Fast User Execution (`user_run`)**:
  * Replace `su -l <user> -c ...` (which initializes PAM sessions, auth stacks, and shell login scripts) with `runuser -u <user> -- /bin/sh -c ...`.
  * Cache `WAYLAND_DISPLAY` (e.g. `wayland-1`) to avoid subshell directory globbing on every command.
* **Low-Latency Input Injection (`click`, `key`, `type`)**:
  * Combine position and button press/release events into a single batched QMP transaction where possible.
  * Remove redundant 50ms and 20ms sleep pauses.
* **Fast-Failing Shell Reloads**:
  * Check `ready_file = vm.shared_dir / "qs_ready"` with a responsive 20ms poll interval.
  * If `qs-bar.service` enters a failed or dead state (due to QML syntax or runtime errors), detect it immediately and dump journalctl logs without stalling for 60 seconds.

### 3.3 Quickshell Motion & Render Architecture (`quickshell/bar/`)
* **Lazy Motion Oscillators**:
  * In `theme/Anim.qml`, ensure ambient phase oscillators (`breathPhase`, `shimmerPhase`, `vitalityPhase`) only run when `Anim.ambient` is active and there are active visual subscribers.
* **Canvas 2D Throttling**:
  * Verify `MujoLivingCanvas.qml` and `LauncherBody.qml` repaints halt completely when windows or overlays are closed.

---

## 4. Verification & Testing Plan

1. **Lifetime & Stability Test**:
   * Run `nix-shell -p python3 --run "python3 nixos/sandbox/test-lifetime.py"` to verify watchdog and lifetime guards (idle, eof, active, reboot).
2. **Nix Flake Evaluation**:
   * Run `nix flake check` to verify syntax and flake module integrity.
3. **Sandbox Derivation Build**:
   * Build the sandbox package (`nix build .#packages.x86_64-linux.sandbox`).
4. **Performance Benchmarking**:
   * Measure cold boot time, warm reload time, screenshot capture latency, and command execution latency.
