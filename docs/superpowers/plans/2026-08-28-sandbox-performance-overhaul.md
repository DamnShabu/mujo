# VM / Sandbox System Performance & Architecture Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul the NixOS sandbox VM and Quickshell subsystem to achieve ≤ 10% bare-metal overhead, sub-40ms screenshots, instant reloads, and eliminate UI frame stutters.

**Architecture:** Optimize QEMU/KVM hardware virtualization flags, accelerate 9p filesystem sharing with `cache=loose`, streamline the MCP server with single-hop zero-copy screenshot pipelines and lightweight `runuser` execution, and optimize Quickshell motion oscillators and canvas redraws.

**Tech Stack:** NixOS, QEMU/KVM, VirtIO (9p, virtio-gpu, virgl), Python (MCP JSON-RPC server), Wayland/Niri, Quickshell (QtQuick/QML).

**Spec:** `docs/superpowers/specs/2026-08-28-sandbox-performance-overhaul-design.md`

## Global Constraints
- Flake absolute path requirement: `--flake` takes an absolute path.
- User identity: Never hardcode "yurii"; use `config.preferences.user.name`.
- Shell proxy: Prefix shell commands with `rtk` when running supported CLI tools.
- Preserved lifetime guarantees: Must pass `nixos/sandbox/test-lifetime.py` at all times.

---

### Task 1: Virtualization & Kernel Boot Optimization

**Files:**
- Modify: `nixos/sandbox/sandbox.nix`

**Interfaces:**
- Consumes: nixpkgs QEMU test driver, `config.preferences.user.name`
- Produces: Optimized QEMU flags, kernel cmdline parameters, and accelerated 9p mount options.

- [ ] **Step 1: Edit `nixos/sandbox/sandbox.nix` with optimized kernel params and QEMU flags**
  Add kernel parameters for fast boot and zero-overhead virtualization (`mitigations=off`, `nowatchdog`, `audit=0`, `nohpet`, `tsc=reliable`, `nomce`, `elevator=none`, `systemd.show_status=auto`, `rd.udev.log_level=3`, `quiet`).
  Configure QEMU with `-machine q35,accel=kvm,kernel-irqchip=on`, `-no-hpet`, `-global kvm-pit.lost_tick_policy=discard`.
  Update `/mnt/nixconf` 9p filesystem options to use `cache=loose` and `posixacl=0`.

- [ ] **Step 2: Verify Nix flake evaluation**
  Run: `nix flake check`
  Expected: Evaluates cleanly with 0 errors.

- [ ] **Step 3: Commit changes**
  ```bash
  git add nixos/sandbox/sandbox.nix
  git commit -m "perf(sandbox): optimize kernel cmdline, QEMU KVM flags, and 9p caching"
  ```

---

### Task 2: Fast-Path Screenshot, Input & Execution Pipelines in MCP Driver

**Files:**
- Modify: `nixos/sandbox/mcp.py`
- Modify: `nixos/sandbox/test-lifetime.py`

**Interfaces:**
- Consumes: QEMU QMP client, guest `/tmp/shared` 9p exchange directory
- Produces: Fast single-hop `screenshot()`, lightweight `user_run()`, low-latency `click()`, and fast-fail `reload()`.

- [ ] **Step 1: Optimize `nixos/sandbox/mcp.py`**
  1. In `screenshot()`: Have `grim` write directly to `/tmp/shared/shot.png` inside the user session and eliminate `run(f"cp ...")`.
  2. In `user_run()`: Use `runuser -u {user_name()} -- /bin/sh -c ...` instead of `su -l` PAM login sessions, with cached `WAYLAND_DISPLAY`.
  3. In `click()` / `send_input()`: Batch QMP input events and eliminate sleep pauses.
  4. In `reload()` and `wait_for_shell()`: Use 20ms poll intervals on `/tmp/shared/qs_ready` and check for immediate unit failure.

- [ ] **Step 2: Run lifetime and regression test suite**
  Run: `nix-shell -p python3 --run "python3 nixos/sandbox/test-lifetime.py"`
  Expected: PASS 4/4 sandbox lifetime checks.

- [ ] **Step 3: Commit changes**
  ```bash
  git add nixos/sandbox/mcp.py nixos/sandbox/test-lifetime.py
  git commit -m "perf(sandbox): single-hop direct screenshot pipeline and fast execution"
  ```

---

### Task 3: Quickshell Motion & Render Optimization

**Files:**
- Modify: `quickshell/bar/theme/Anim.qml`
- Modify: `quickshell/bar/components/MujoLivingCanvas.qml`

**Interfaces:**
- Consumes: Quickshell runtime, SettingsBus
- Produces: Lazy ambient phase oscillators and throttled canvas repaints.

- [ ] **Step 1: Optimize `quickshell/bar/theme/Anim.qml`**
  Ensure ambient phase oscillators (`breathPhase`, `shimmerPhase`, `vitalityPhase`) only run when `Anim.ambient` is true, reduceMotion is false, and performanceMode is false.
  Ensure zero-allocation helper functions.

- [ ] **Step 2: Optimize `quickshell/bar/components/MujoLivingCanvas.qml`**
  Ensure phase animations only run when `root.visible` is true and `Anim.illustrations` is active.

- [ ] **Step 3: Verify Nix flake evaluation**
  Run: `nix flake check`
  Expected: Evaluates cleanly.

- [ ] **Step 4: Commit changes**
  ```bash
  git add quickshell/bar/theme/Anim.qml quickshell/bar/components/MujoLivingCanvas.qml
  git commit -m "perf(quickshell): optimize ambient phase oscillators and canvas rendering"
  ```

---

### Task 4: Full System Verification, Benchmarking & Documentation

**Files:**
- Modify: `docs/superpowers/specs/2026-08-28-sandbox-performance-overhaul-design.md`

- [ ] **Step 1: Run complete test suite and flake check**
  Run: `nix-shell -p python3 --run "python3 nixos/sandbox/test-lifetime.py"`
  Run: `nix flake check`

- [ ] **Step 2: Measure performance metrics**
  Measure lifetime execution, command latency, and verify speedups.

- [ ] **Step 3: Document benchmark results and summary**
  Provide comprehensive summary of what was changed, performance gains, and remaining bottlenecks.
