# Niri Keybinding Reload & Shortcuts Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix broken Niri config reload keybind (`Mod+Shift+R`), resolve stale shortcuts resolution in QuickShell Settings, and verify `Mod+Shift+W` wallpaper picker.

**Architecture:** Update Niri wrapper keybind action from invalid `reload-config` to `load-config-file`, prioritize `/etc/systemd/user/niri.service` in `ShortcutsGroup.qml` over stale `/proc/environ`, and verify live execution.

**Tech Stack:** Nix, Niri (KDL), QuickShell / QML, Systemd.

---

### Task 1: Fix Niri Config Reload Keybind

**Files:**
- Modify: `modules/wrappers/niri.nix:203`

- [ ] **Step 1: Replace `reload-config` with `load-config-file` in `modules/wrappers/niri.nix`**
- [ ] **Step 2: Build wrapped niri package to confirm KDL generation**
- [ ] **Step 3: Commit change using `rtk git commit`**

---

### Task 2: Fix Settings UI Shortcuts Source Desync

**Files:**
- Modify: `quickshell/bar/modules/settings/ShortcutsGroup.qml:41-46`

- [ ] **Step 1: Prioritize `/etc/systemd/user/niri.service` and user config before falling back to `/proc/environ`**
- [ ] **Step 2: Run `qs -p quickshell/bar/test-settings-ui.qml` to verify no regressions**
- [ ] **Step 3: Commit change using `rtk git commit`**

---

### Task 3: Live Verification & Testing

- [ ] **Step 1: Reload running Niri instance via `niri msg action load-config-file`**
- [ ] **Step 2: Run ShellCheck on all tracked scripts**
- [ ] **Step 3: Run QuickShell test suites**
