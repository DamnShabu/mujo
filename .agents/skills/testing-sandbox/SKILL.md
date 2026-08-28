---
name: testing-sandbox
description: Use when testing or visually inspecting quickshell desktop UI, QML changes, bar widgets, wallpaper, dialogs, or compositor keybinds in the graphical sandbox VM.
---

# Testing Sandbox (Disposable Graphical VM)

## Overview

The testing sandbox (`nixos/sandbox/`) is a throwaway, virgl-accelerated graphical NixOS VM with an embedded MCP stdio server. It boots an isolated Wayland/Niri session with Quickshell running against a live 9p-mount of the repository working tree (`/mnt/nixconf`).

It allows any agent to make QML changes, reload the running shell, take screenshots, inject input, and inspect logs **without rebuilding NixOS or touching the host desktop session**.

```
Host Working Tree (quickshell/bar/) ──(9p ro-mount)──> Guest (/mnt/nixconf -> /etc/xdg/quickshell/bar)
                                                                 │
                                                            qs-bar.service
                                                                 │
Host Agent ──(MCP stdio: nix run .#sandbox)──> MCP Server ──> [reload | screenshot | click | key | logs | exec]
```

---

## When to Use

- **Visual validation**: Inspecting bar layout, widget alignment, fonts, colors, dialogs, and notifications after editing QML.
- **Interactive UI testing**: Clicking widgets, expanding menus, typing into input boxes, or triggering compositor keybinds.
- **Debugging QML crashes**: Viewing journal logs (`logs`) when quickshell fails to load or enters a crash-restart loop.
- **Testing guest commands**: Executing shell commands (`exec`) inside the clean guest environment.

### When NOT to Use

- Non-UI system configuration checks (use `nix flake check` or unit tests instead).
- Evaluating standalone CLI packages or formatting code.

---

## The Core Development Loop (Edit → Reload → Screenshot)

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│  1. Edit QML    │  ──>  │  2. MCP reload  │  ──>  │ 3. Screenshot   │
│  (working tree) │       │  (instant swap) │       │  (visual check) │
└─────────────────┘       └─────────────────┘       └─────────────────┘
                                   │
                           (if error/crash)
                                   ▼
                          ┌─────────────────┐
                          │  4. MCP logs    │
                          │  (diagnose fix) │
                          └─────────────────┘
```

1. **Edit**: Modify files in `quickshell/bar/` directly in the host repository.
2. **Reload**: Call the MCP tool `reload`.
   - Restarts `qs-bar.service` in the guest.
   - Waits for the QML configuration load counter to increment (~20s in VM) plus a 3-second render settle delay.
   - If the load fails or quickshell crashes, returns the last 30 journal lines automatically.
3. **Screenshot**: Call the MCP tool `screenshot`.
   - Captures the 1280x800 Wayland surface via `grim` and returns the PNG image.
4. **Iterate**: If adjustments are needed, repeat steps 1–3. **No host rebuild (`nh os switch`) is required**.

---

## MCP Tool Reference

| Tool | Parameters | Description |
|---|---|---|
| `screenshot` | *(none)* | Takes a PNG screenshot of the sandbox Wayland display (1280x800). Returns dimensions and image data. |
| `reload` | *(none)* | Restarts `qs-bar.service` to load working-tree edits; waits for load event and frame settle. |
| `click` | `x` (int), `y` (int), `button` (optional: `"left"` \| `"middle"` \| `"right"`) | Simulates mouse click at absolute pixel coordinates on the 1280x800 screen. |
| `type` | `text` (string) | Sends keyboard text characters into the currently focused window. |
| `key` | `keys` (string) | Sends key combo in QEMU sendkey format (e.g. `'meta_l-spc'`, `'meta_l-comma'`, `'ctrl-alt-t'`, `'ret'`). |
| `logs` | `unit` (optional, default `"qs-bar"`), `lines` (optional, default `100`) | Reads tail of a systemd user journal inside the sandbox. |
| `exec` | `cmd` (string) | Runs a bash command as `root` in the guest VM and returns combined stdout/stderr. |

---

## Common Workflows

### 1. Opening Overlays and Menus

Use `key` to trigger Niri shortcuts defined in `modules/wrappers/niri.nix`:

- **Launcher / App Drawer**: `key(keys="meta_l-spc")`
- **Settings App**: `key(keys="meta_l-comma")`
- **Terminal**: `key(keys="meta_l-ret")`

After sending a key, call `screenshot` to verify that the menu or window appeared correctly.

### 2. Clicking Interactive Elements

Use `click(x, y)` with pixel coordinates from a previous screenshot. The MCP server automatically scales pixel coordinates (0..1280, 0..800) to QEMU's absolute tablet axis (0..32767).

```
# Example: Click top bar at (x=640, y=15)
click(x=640, y=15, button="left")
screenshot()
```

### 3. Testing Settings Changes

The guest sandbox boots with default settings seeded in `~/.config/qsshell/settings.json`.
Because `SettingsBus.qml` reads stored JSON values, editing *defaults* in `Theme.qml` won't override keys that already exist in the guest's `settings.json`.

To test settings modifications in the sandbox:
- Run `exec(cmd="su -l $(id -nu 1000) -c 'mujo settings set <key> <value>'")`
- Or open settings with `key(keys="meta_l-comma")` and click the UI controls.

### 4. Diagnosing QML Errors

If `reload` reports that the shell failed to restart, inspect detailed QML engine output:

```
logs(unit="qs-bar", lines=150)
```

Look for:
- Missing `qmldir` registrations (`"X is not a type"` or `ReferenceError`).
- Syntax errors or unmet import paths.
- IPC failure messages.

---

## Key Rules & Best Practices

1. **Initial Boot Latency**: The first tool call takes ~45 seconds (VM boot + compositor start + quickshell compilation). Do not abort or assume a hang; subsequent tool calls take 1–3 seconds.
2. **Never Rebuild Host for Sandbox Testing**: The guest's `/etc/xdg/quickshell/bar` points to `/mnt/nixconf/quickshell/bar` (9p working-tree mount). Edits are live immediately upon calling `reload`.
3. **Always Register New Components**: Any new `.qml` file added under `components/`, `services/`, or `modules/<domain>/` must be listed in that directory's `qmldir`.
4. **Headless & Isolated**: The sandbox runs offscreen via `egl-headless` using the host's GPU render node (`/dev/dri/renderD128`). It does not draw to the host screen or interfere with host windows.
5. **Disposable Root**: The guest root filesystem is a tmpfs. Any files created inside the guest die when the MCP connection closes. Host files under `/mnt/nixconf` are mounted strictly read-only.
