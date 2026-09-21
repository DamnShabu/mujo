# Design Spec: skwd-wall Integration & Wallpaper Implementation Purge

**Date**: 2026-09-21  
**Status**: Proposed  

## 1. Context & Motivation

The system currently employs a custom wallpaper implementation comprised of:
- A QuickShell background layer-shell surface (`quickshell/bar/modules/desktop/Wallpaper.qml`) rendering static images, video via QtMultimedia, and Wallpaper Engine scenes.
- A custom C daemon (`quickshell/cursor-tracker/`) capturing `/dev/input` mouse events for parallax zoom/pan effects.
- A Python backend helper (`quickshell/wallpaper-engine/mujo-wallpaper-engine.py`) and upstream `linux-wallpaperengine` (~1.47 GiB closure).
- Extensive QuickShell settings UI panels (`WallpaperBrowseGroup`, `WallpaperEffectsGroup`, `WallhavenControls`, `WallhavenGrid`, `WallhavenDetailModal`, `WallpaperEngineControls`, `WallpaperEngineGrid`, `WallpaperEngineDetailModal`, `WallpaperLibraryGrid`, `TagQuery.js`).
- QuickShell background services (`Wallhaven.qml`, `WallpaperEngine.qml`, `WallpaperDownloads.qml`, `WallpaperDownloadWorker.qml`).
- `mujo wallpaper` CLI subcommands in `quickshell/mujo.sh`.
- Test suites (`test-wallpaper-panel.qml`).

This design replaces the entire custom wallpaper stack with [skwd-wall](https://github.com/liixini/skwd-wall) (`1.0.0-beta.17`), an aesthetics-first standalone wallpaper selector and engine supporting images, videos, and Wallpaper Engine scenes with high performance, automated semantic tagging (SigLIP 2 via `skwd-lens`), and native Wayland layer-shell rendering (`skwd-paper-v2`).

---

## 2. Architecture & Components

```
                        ┌──────────────────────────────────────────────┐
                        │              Niri Compositor                 │
                        └──────────────┬───────────────────────────────┘
                                       │
           ┌───────────────────────────┴───────────────────────────┐
           │                                                       │
  Keybind: Mod+Shift+W                             layer-shell (wlr-layer-shell)
  Desktop menu click                                               │
           │                                                       ▼
           ▼                                            ┌─────────────────────┐
  ┌─────────────────┐                                   │    skwd-paper-v2    │
  │   skwd-wall-v2  │ ──────── IPC / Control ─────────> │ (wallpaper renderer)│
  │  (UI selector)  │                                   └─────────────────────┘
  └─────────────────┘                                              ▲
           ▲                                                       │
           │                                                       │
           └──────────────────> ┌─────────────────────┐ ───────────┘
                                │     skwd-walld      │
                                │  (systemd daemon)   │
                                └──────────┬──────────┘
                                           │
                                           ▼
                                ┌─────────────────────┐
                                │  skwd-lens (SigLIP) │
                                └─────────────────────┘
```

### Key Differences After Purge:
1. **Desktop Background Rendering**: QuickShell no longer draws layer-shell background surfaces (`Wallpaper.qml` removed). `skwd-paper-v2` managed by `skwd-walld` directly draws to Wayland layer-shell.
2. **Settings**: Appearance page in QuickShell Settings focuses cleanly on **Themes & Colors** and **Motion Dynamics**. The wallpaper library, Wallhaven browser, and Wallpaper Engine panels are removed.
3. **Selector**: Launched via Niri keybind `Mod+Shift+W`, app launcher, or right-clicking on the desktop ("Wallpaper" context action).
4. **Closure Footprint**: Eliminates `linux-wallpaperengine` (~1.47 GiB), C `cursor-tracker`, and Python scripts.

---

## 3. Subsystem Modifications

### 3.1. Flake & NixOS Host Integration
- **`flake.nix`**:
  - Add input `skwd-wall.url = "github:liixini/skwd-wall";`.
- **`nixos/desktop/skwd-wall.nix`** (new module):
  - Import `inputs.skwd-wall.nixosModules.default`.
  - Configure `services.skwd-deck.enable = true;` to enable `skwd-walld` systemd user service under `graphical-session.target`.
  - Provide a compatibility wrapper `pkgs.writeShellScriptBin "skwd-wall" 'exec skwd-wall-v2 "$@"'`.
  - Configure impermanence:
    ```nix
    persistence.data.directories = [
      ".config/skwd"
      ".local/share/skwd"
      ".local/state/skwd"
    ];
    ```
- **`nixos/hosts/main/configuration.nix`**:
  - Add `self.nixosModules.skwd-wall` to host modules.
- **`nixos/desktop/quickshell.nix`**:
  - Remove `pkgs.linux-wallpaperengine`, `qs.mujo-wallpaper-engine`, and `qs.cursor-tracker` from `environment.systemPackages` and `systemd.user.services.qs-bar.path`.

### 3.2. Packaging & Derivations Purge
- **`quickshell/_default.nix`**:
  - Delete `mujo-wallpaper-engine` derivation.
  - Delete `cursor-tracker` derivation.
- **File Deletions**:
  - Delete `quickshell/cursor-tracker/` (`cursor-tracker.c`).
  - Delete `quickshell/wallpaper-engine/` (`mujo-wallpaper-engine.py`).

### 3.3. Compositor (Niri) Integration
- **`modules/wrappers/niri.nix`**:
  - Remove layer-rule `{ namespace = "^qs-wallpaper-bg"; }`.
  - Add keybind `"Mod+Shift+W".spawn = "skwd-wall-v2";`.
  - Add window-rule:
    ```nix
    {
      matches = [{app-id = "^skwd-wall-v2$";}];
      open-floating = true;
    }
    ```

### 3.4. QuickShell Desktop Shell
- **`quickshell/bar/shell.qml`**:
  - Remove `Wallpaper {}` instance (lines 165–168).
- **`quickshell/bar/modules/desktop/Wallpaper.qml`**:
  - Delete file.
- **`quickshell/bar/modules/desktop/qmldir`**:
  - Remove `Wallpaper Wallpaper.qml`.
- **`quickshell/bar/modules/desktop/DesktopWidgets.qml`**:
  - Replace `sub` wallpaper menu items (which ran `mujo settings wallpaper` and `mujo wallpaper random`) with a single direct launcher:
    ```qml
    items.push({ icon: "wallpaper", label: "Wallpaper", cmd: ["skwd-wall-v2"] })
    ```

### 3.5. QuickShell Settings App
- **`quickshell/bar/settings.qml`**:
  - Update `appearance` category:
    - Subtitle: `"Theme presets, accent colors, and motion dynamics"`
    - Sub-tabs: only `themes` and `motion` (remove `wallpapers` and `effects`).
    - Keys: remove `wallpapers`, `wallpaper`, `wallhaven`, `wallpaperengine`, `effects`, `parallax`.
- **`quickshell/bar/modules/settings/AppearancePage.qml`**:
  - Subtitle: `"Theme presets, accent colors, and motion dynamics."`
  - Remove `wallpapers` and `effects` from `sections`.
  - Remove `cardMap` entries for Wallpaper Engine Performance, Parallax & Background.
  - Remove `aliases` for `library`, `wallhaven`, `wallpaperengine`.
  - Remove wallpaper properties (`localList`, `currentImage`, `letterbox`, `motionOn`, `wpSource`), `runWp()`, `refreshLocal()`, `FileView` for `wallpaper.json`, `listProc`, `WallpaperDownloads` connections.
  - Remove `effectsSection` and `wallpapersSection` components.
- **`quickshell/bar/modules/settings/SearchIndex.js`**:
  - Remove entries for "Wallpaper Library", "Wallhaven Online Explorer", "Wallpaper Engine Steam Workshop", "Wallpaper Engine Performance", and "Parallax & Background".
- **Component Deletions (`quickshell/bar/modules/settings/`)**:
  - `WallpaperBrowseGroup.qml`
  - `WallpaperEffectsGroup.qml`
  - `WallpaperLibraryGrid.qml`
  - `WallhavenControls.qml`
  - `WallhavenGrid.qml`
  - `WallhavenDetailModal.qml`
  - `WallpaperEngineControls.qml`
  - `WallpaperEngineGrid.qml`
  - `WallpaperEngineDetailModal.qml`
  - `TagQuery.js`
- **`quickshell/bar/modules/settings/qmldir`**:
  - Unregister all deleted settings components.

### 3.6. QuickShell Services Purge
- **Service Deletions (`quickshell/bar/services/`)**:
  - `Wallhaven.qml`
  - `WallpaperEngine.qml`
  - `WallpaperDownloads.qml`
  - `WallpaperDownloadWorker.qml`
- **`quickshell/bar/services/qmldir`**:
  - Remove `Wallhaven`, `WallpaperEngine`, `WallpaperDownloads`, and `WallpaperDownloadWorker` singletons.

### 3.7. CLI Cleanup (`quickshell/mujo.sh`)
- Remove `wallpaper_usage` and all helper functions (`wallpaper_list`, `wallpaper_search`, `wallpaper_details`, `wallpaper_tag`, etc.).
- Remove `wallpaper)` case statement in main CLI command switch.
- Remove `wallpaper` from top-level help text.
- In `theme` command: Remove `wallpaper.json` background sync block (lines 1043–1050).

### 3.8. Tests & Documentation
- Delete `quickshell/bar/test-wallpaper-panel.qml`.
- Update `quickshell/bar/test-settings-ui.qml`:
  - Appearance tabs check updated from 5 tabs to `["themes", "motion"]`.
  - Remove route assertions for `wallpapers` and `wallpaperengine`.
- Update `AGENTS.md` and `quickshell/bar/AGENTS.md`:
  - Remove `wallpaper-panel` from the QuickShell test loop.
  - Remove references to `mujo-wallpaper-engine`, `cursor-tracker`, and `wallpaper.json`.
- Update `docs/overhaul-ledger.md`.

---

## 4. Verification Plan

1. **Flake & Build Validation**:
   - Run `nix flake check` to verify the flake evaluates cleanly and `checks.hostMain` builds without errors.
2. **Offline Self-Checks**:
   - Run `nix shell nixpkgs#shellcheck -c shellcheck -S warning -e SC1090 -P quickshell $(git ls-files '*.sh')` to verify shell script integrity.
   - Run QuickShell test suite:
     ```bash
     cd quickshell/bar
     for t in icons grid notifications shelf settings-ui security-ui desktop scroll vm-service reorder-list greeter bar-modular; do
       qs -p "./test-$t.qml"
     done
     ```
3. **Functional Verification**:
   - Verify `skwd-wall` suite binaries are present on system path.
   - Verify `systemctl --user status skwd-walld.service` starts cleanly under graphical session.
   - Verify `skwd-wall-v2` launches via `Mod+Shift+W` and renders its UI.
   - Verify QuickShell bar and standalone settings app load without QML errors or missing component warnings.
