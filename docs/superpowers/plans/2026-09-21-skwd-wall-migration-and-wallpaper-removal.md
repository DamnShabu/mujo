# skwd-wall Integration & Wallpaper Implementation Purge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the `skwd-wall` wallpaper suite and completely remove the existing legacy wallpaper implementation across QuickShell, NixOS modules, CLI, and helper packages.

**Architecture:** Add `skwd-wall` via flake input and manage its daemon/binaries through a new `nixos/desktop/skwd-wall.nix` NixOS module with impermanence support. Purge all QuickShell layer-shell wallpaper surfaces, Settings UI panels, background services, C `cursor-tracker`, Python `mujo-wallpaper-engine`, and `mujo wallpaper` CLI subcommands.

**Tech Stack:** NixOS (Flake, Nix modules, systemd user services), Niri Wayland Compositor, QuickShell (QML/Qt6), Bash.

**Spec:** `docs/superpowers/specs/2026-09-21-skwd-wall-migration-and-wallpaper-removal-design.md`

## Global Constraints

- Never hardcode "yurii"; use `config.preferences.user.name` where applicable.
- In Niri / Wayland, `skwd-wall-v2` is launched via `Mod+Shift+W` or desktop context menu.
- Shell commands must be prefixed with `rtk` when running supported CLI tools (`git`, `cargo`, `ls`, `grep`, `find`, etc.).
- Shell scripts must pass `nix shell nixpkgs#shellcheck -c shellcheck -S warning -e SC1090 -P quickshell $(git ls-files '*.sh')`.
- QuickShell self-checks must pass without QML errors or missing component warnings.
- `nix flake check` must evaluate and build host toplevel cleanly.

---

### Task 1: Flake Input & NixOS Module (`skwd-wall`)

**Files:**
- Modify: `flake.nix:94-96`
- Create: `nixos/desktop/skwd-wall.nix`
- Modify: `nixos/hosts/main/configuration.nix:70-75`
- Modify: `nixos/desktop/quickshell.nix:74,121`

**Interfaces:**
- Consumes: `inputs.skwd-wall.nixosModules.default`
- Produces: `services.skwd-deck.enable = true`, `skwd-wall` binary wrapper, impermanence bindings for `.config/skwd`, `.local/share/skwd`, `.local/state/skwd`

- [ ] **Step 1: Add skwd-wall input in flake.nix**

Add `skwd-wall` to `inputs` in `flake.nix`:
```nix
    skwd-wall = {
      url = "github:liixini/skwd-wall";
    };
```

- [ ] **Step 2: Create nixos/desktop/skwd-wall.nix**

```nix
{inputs, ...}: {
  flake.nixosModules.skwd-wall = {pkgs, ...}: {
    imports = [
      inputs.skwd-wall.nixosModules.default
    ];

    services.skwd-deck.enable = true;

    # Convenience wrapper: 'skwd-wall' invokes 'skwd-wall-v2'
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "skwd-wall" ''
        exec skwd-wall-v2 "$@"
      '')
    ];

    persistence.data.directories = [
      ".config/skwd"
      ".local/share/skwd"
      ".local/state/skwd"
    ];
  };
}
```

- [ ] **Step 3: Register self.nixosModules.skwd-wall in configuration.nix**

In `nixos/hosts/main/configuration.nix`, add `self.nixosModules.skwd-wall` to `imports`.

- [ ] **Step 4: Clean legacy packages in nixos/desktop/quickshell.nix**

In `nixos/desktop/quickshell.nix`:
- Remove `qs.mujo-wallpaper-engine`, `pkgs.linux-wallpaperengine`, and `qs.cursor-tracker` from `environment.systemPackages` (line 74).
- Remove `qs.cursor-tracker`, `qs.mujo-wallpaper-engine`, and `linux-wallpaperengine` from `systemd.user.services.qs-bar.path` (line 121).

- [ ] **Step 5: Verify flake evaluation**

Run: `nix flake check --no-build`
Expected: Evaluates cleanly.

- [ ] **Step 6: Commit**

```bash
rtk git add flake.nix nixos/desktop/skwd-wall.nix nixos/hosts/main/configuration.nix nixos/desktop/quickshell.nix
rtk git commit -m "feat(nixos): add skwd-wall module and drop legacy wallpaper packages"
```

---

### Task 2: Purge Legacy Helper Derivations & Backend Files

**Files:**
- Modify: `quickshell/_default.nix:90-112`
- Delete: `quickshell/cursor-tracker/`
- Delete: `quickshell/wallpaper-engine/`

**Interfaces:**
- Consumes: None
- Produces: Streamlined `quickshell/_default.nix` without `cursor-tracker` or `mujo-wallpaper-engine`

- [ ] **Step 1: Remove mujo-wallpaper-engine and cursor-tracker from quickshell/_default.nix**

Delete lines 90–112 in `quickshell/_default.nix` containing `mujo-wallpaper-engine` and `cursor-tracker`.

- [ ] **Step 2: Delete legacy backend source directories**

Delete directories:
- `quickshell/cursor-tracker/`
- `quickshell/wallpaper-engine/`

- [ ] **Step 3: Verify quickshell derivation evaluation**

Run: `nix eval .#checks.x86_64-linux.hostMain.drvPath`
Expected: Evaluates without referencing deleted packages.

- [ ] **Step 4: Commit**

```bash
rtk git add quickshell/_default.nix
rtk git rm -r quickshell/cursor-tracker quickshell/wallpaper-engine
rtk git commit -m "refactor(quickshell): purge cursor-tracker and wallpaper-engine derivations"
```

---

### Task 3: Compositor (Niri) Updates

**Files:**
- Modify: `modules/wrappers/niri.nix:98-100,317-323`

**Interfaces:**
- Consumes: `skwd-wall-v2` binary
- Produces: `Mod+Shift+W` keybind, floating window rule for `skwd-wall-v2`, cleanup of backdrop layer rule

- [ ] **Step 1: Add keybind and floating window rule, remove backdrop layer rule**

In `modules/wrappers/niri.nix`:
- Add keybind `"Mod+Shift+W".spawn = "skwd-wall-v2";`.
- Add window rule:
  ```nix
  {
    matches = [{app-id = "^skwd-wall-v2$";}];
    open-floating = true;
  }
  ```
- Remove layer rule:
  ```nix
  {
    matches = [
      {namespace = "^qs-wallpaper-bg";}
    ];
    place-within-backdrop = true;
  }
  ```

- [ ] **Step 2: Verify niri configuration evaluation**

Run: `nix eval .#nixosConfigurations.main.config.programs.niri.finalConfig`
Expected: Evaluates cleanly with new keybind and window rule.

- [ ] **Step 3: Commit**

```bash
rtk git add modules/wrappers/niri.nix
rtk git commit -m "feat(niri): bind Mod+Shift+W to skwd-wall-v2 and drop qs-wallpaper-bg rule"
```

---

### Task 4: QuickShell Desktop Shell Cleanup

**Files:**
- Modify: `quickshell/bar/shell.qml:165-169`
- Modify: `quickshell/bar/modules/desktop/qmldir:1`
- Modify: `quickshell/bar/modules/desktop/DesktopWidgets.qml:862-865`
- Delete: `quickshell/bar/modules/desktop/Wallpaper.qml`

**Interfaces:**
- Consumes: `skwd-wall-v2`
- Produces: QuickShell shell without layer-shell wallpaper surface

- [ ] **Step 1: Remove Wallpaper {} from shell.qml**

Remove lines 165–169 in `quickshell/bar/shell.qml`:
```qml
    // Per-screen wallpaper (image / video) with optional cursor-tracking
    // zoom/pan, plus blurred backdrop surfaces for niri's overview.
    // Config: ~/.config/quickshell/wallpaper.json  (managed by `mujo wallpaper`).
    Wallpaper {}
```

- [ ] **Step 2: Update desktop context menu in DesktopWidgets.qml**

In `quickshell/bar/modules/desktop/DesktopWidgets.qml`, replace the nested `Wallpaper` menu items (which executed `mujo settings wallpaper` and `mujo wallpaper random`) with a single item:
```qml
            items.push({ icon: "wallpaper", label: "Wallpaper", cmd: ["skwd-wall-v2"] })
```

- [ ] **Step 3: Delete Wallpaper.qml and remove from modules/desktop/qmldir**

Delete `quickshell/bar/modules/desktop/Wallpaper.qml`.
In `quickshell/bar/modules/desktop/qmldir`, remove line:
```
Wallpaper Wallpaper.qml
```

- [ ] **Step 4: Verify desktop module self-check**

Run: `qs -p quickshell/bar/test-desktop.qml`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
rtk git add quickshell/bar/shell.qml quickshell/bar/modules/desktop/DesktopWidgets.qml quickshell/bar/modules/desktop/qmldir
rtk git rm quickshell/bar/modules/desktop/Wallpaper.qml
rtk git commit -m "refactor(quickshell): remove custom Wallpaper surface and route desktop menu to skwd-wall-v2"
```

---

### Task 5: QuickShell Background Services Purge

**Files:**
- Delete: `quickshell/bar/services/Wallhaven.qml`
- Delete: `quickshell/bar/services/WallpaperEngine.qml`
- Delete: `quickshell/bar/services/WallpaperDownloads.qml`
- Delete: `quickshell/bar/services/WallpaperDownloadWorker.qml`
- Modify: `quickshell/bar/services/qmldir:13-16`

**Interfaces:**
- Consumes: None
- Produces: Clean `services` module without Wallhaven and WallpaperEngine singletons

- [ ] **Step 1: Delete wallpaper service files**

Delete:
- `quickshell/bar/services/Wallhaven.qml`
- `quickshell/bar/services/WallpaperEngine.qml`
- `quickshell/bar/services/WallpaperDownloads.qml`
- `quickshell/bar/services/WallpaperDownloadWorker.qml`

- [ ] **Step 2: Unregister services in quickshell/bar/services/qmldir**

Remove lines 13–16 from `quickshell/bar/services/qmldir`:
```
singleton Wallhaven Wallhaven.qml
singleton WallpaperEngine WallpaperEngine.qml
singleton WallpaperDownloads WallpaperDownloads.qml
WallpaperDownloadWorker WallpaperDownloadWorker.qml
```

- [ ] **Step 3: Commit**

```bash
rtk git add quickshell/bar/services/qmldir
rtk git rm quickshell/bar/services/Wallhaven.qml quickshell/bar/services/WallpaperEngine.qml quickshell/bar/services/WallpaperDownloads.qml quickshell/bar/services/WallpaperDownloadWorker.qml
rtk git commit -m "refactor(quickshell): remove Wallhaven and WallpaperEngine background services"
```

---

### Task 6: QuickShell Settings App UI Purge

**Files:**
- Modify: `quickshell/bar/settings.qml:60-68`
- Modify: `quickshell/bar/modules/settings/AppearancePage.qml`
- Modify: `quickshell/bar/modules/settings/SearchIndex.js:167-202`
- Modify: `quickshell/bar/modules/settings/qmldir`
- Delete: `quickshell/bar/modules/settings/WallpaperBrowseGroup.qml`
- Delete: `quickshell/bar/modules/settings/WallpaperEffectsGroup.qml`
- Delete: `quickshell/bar/modules/settings/WallpaperLibraryGrid.qml`
- Delete: `quickshell/bar/modules/settings/WallhavenControls.qml`
- Delete: `quickshell/bar/modules/settings/WallhavenGrid.qml`
- Delete: `quickshell/bar/modules/settings/WallhavenDetailModal.qml`
- Delete: `quickshell/bar/modules/settings/WallpaperEngineControls.qml`
- Delete: `quickshell/bar/modules/settings/WallpaperEngineGrid.qml`
- Delete: `quickshell/bar/modules/settings/WallpaperEngineDetailModal.qml`
- Delete: `quickshell/bar/modules/settings/TagQuery.js`

**Interfaces:**
- Consumes: None
- Produces: Streamlined AppearancePage with only Themes & Colors and Motion Dynamics

- [ ] **Step 1: Delete settings wallpaper components**

Delete:
- `quickshell/bar/modules/settings/WallpaperBrowseGroup.qml`
- `quickshell/bar/modules/settings/WallpaperEffectsGroup.qml`
- `quickshell/bar/modules/settings/WallpaperLibraryGrid.qml`
- `quickshell/bar/modules/settings/WallhavenControls.qml`
- `quickshell/bar/modules/settings/WallhavenGrid.qml`
- `quickshell/bar/modules/settings/WallhavenDetailModal.qml`
- `quickshell/bar/modules/settings/WallpaperEngineControls.qml`
- `quickshell/bar/modules/settings/WallpaperEngineGrid.qml`
- `quickshell/bar/modules/settings/WallpaperEngineDetailModal.qml`
- `quickshell/bar/modules/settings/TagQuery.js`

- [ ] **Step 2: Update quickshell/bar/modules/settings/qmldir**

Remove entries for deleted components (lines 1–7 and 12–13):
- `WallpaperBrowseGroup`
- `WallpaperEffectsGroup`
- `WallhavenControls`
- `WallpaperEngineControls`
- `WallpaperLibraryGrid`
- `WallhavenGrid`
- `WallpaperEngineGrid`
- `WallhavenDetailModal`
- `WallpaperEngineDetailModal`

- [ ] **Step 3: Update quickshell/bar/modules/settings/AppearancePage.qml**

Refactor `AppearancePage.qml` to:
- Subtitle: `"Theme presets, accent colors, and motion dynamics."`
- Keep only two sections: `themes` and `motion`:
  ```qml
  sections: [
      { id: "themes", label: "Themes & Colors", component: themesSection,
        description: "Pick a palette, set an accent, and tune how solid surfaces are." },
      { id: "motion", label: "Motion Dynamics", component: motionSection,
        description: "How fast the desktop animates, domain by domain, down to not at all." }
  ]
  ```
- Remove all wallpaper-related properties (`localList`, `currentImage`, `letterbox`, `motionOn`, `wpSource`), functions (`runWp`, `refreshLocal`), `FileView`, `listProc`, and `WallpaperDownloads` connections.
- Remove `effectsSection` and `wallpapersSection`.
- Remove `cardMap` entries for Wallpaper Engine and Parallax.
- Remove `aliases` and simplify `revealCard`.

- [ ] **Step 4: Update quickshell/bar/settings.qml**

In `settings.qml` Appearance category:
- Subtitle: `"Theme presets, accent colors, and motion dynamics"`
- Subs:
  ```qml
  subs: [
      { id: "themes", label: "Themes & Colors", icon: "palette" },
      { id: "motion", label: "Motion Dynamics", icon: "animation" }
  ]
  ```
- Keys: remove `wallpapers`, `wallpaper`, `wallhaven`, `wallpaperengine`, `effects`, `parallax`.

- [ ] **Step 5: Clean search index in SearchIndex.js**

In `quickshell/bar/modules/settings/SearchIndex.js`, delete entries:
- `Wallpaper Library`
- `Wallhaven Online Explorer`
- `Wallpaper Engine Steam Workshop`
- `Wallpaper Engine Performance`
- `Parallax & Background`

- [ ] **Step 6: Commit**

```bash
rtk git add quickshell/bar/modules/settings/qmldir quickshell/bar/modules/settings/AppearancePage.qml quickshell/bar/settings.qml quickshell/bar/modules/settings/SearchIndex.js
rtk git rm quickshell/bar/modules/settings/Wallpaper*.qml quickshell/bar/modules/settings/Wallhaven*.qml quickshell/bar/modules/settings/TagQuery.js
rtk git commit -m "refactor(settings): remove wallpaper tabs, controls, and search cards"
```

---

### Task 7: CLI (`mujo.sh`) Cleanup

**Files:**
- Modify: `quickshell/mujo.sh:22,340-530,1043-1050,1083-1224`

**Interfaces:**
- Consumes: None
- Produces: `mujo` CLI free of legacy `wallpaper` subcommands

- [ ] **Step 1: Remove wallpaper subcommand and functions from mujo.sh**

In `quickshell/mujo.sh`:
- Remove `wallpaper <subcommand>` from general help synopsis (line 22).
- Remove `wallpaper_usage()` and all helper functions (`wallpaper_list`, `wallpaper_search`, `wallpaper_details`, `wallpaper_tag`) around lines 340–530.
- Remove `wallpaper)` case block from the CLI dispatcher (lines 1083–1224).
- In the `theme` command: remove lines 1043–1050 that synced background color into `wallpaper.json`.

- [ ] **Step 2: Run shellcheck verification**

Run: `nix shell nixpkgs#shellcheck -c shellcheck -S warning -e SC1090 -P quickshell $(git ls-files '*.sh')`
Expected: Exits 0 silently.

- [ ] **Step 3: Commit**

```bash
rtk git add quickshell/mujo.sh
rtk git commit -m "refactor(cli): remove mujo wallpaper subcommands and config sync"
```

---

### Task 8: Tests & Documentation Updates

**Files:**
- Delete: `quickshell/bar/test-wallpaper-panel.qml`
- Modify: `quickshell/bar/test-settings-ui.qml:74-79,157-164,226-228`
- Modify: `quickshell/bar/AGENTS.md:56`
- Modify: `AGENTS.md:73`
- Modify: `docs/overhaul-ledger.md`

**Interfaces:**
- Consumes: None
- Produces: Test suite and documentation aligned with the new wallpaper architecture

- [ ] **Step 1: Delete test-wallpaper-panel.qml**

Delete `quickshell/bar/test-wallpaper-panel.qml`.

- [ ] **Step 2: Update test-settings-ui.qml**

In `quickshell/bar/test-settings-ui.qml`:
- Update Appearance sub-tabs check from 4 tabs to 2 (`["themes", "motion"]`).
- Remove route alias tests for `wallpapers` and `wallpaperengine`.
- Update `revealCard` checks to test `themes` and `motion` instead of `wallpapers`.

- [ ] **Step 3: Run test-settings-ui.qml**

Run: `qs -p quickshell/bar/test-settings-ui.qml`
Expected: PASS

- [ ] **Step 4: Update AGENTS.md and quickshell/bar/AGENTS.md**

- In `quickshell/bar/AGENTS.md`: Remove `wallpaper-panel` from test list and remove `wallpaper.json` from config documentation.
- In `AGENTS.md`: Remove `wallpaper-panel` from test loop (line 73) and remove `mujo-wallpaper-engine, cursor-tracker` from quickshell derivations list (line 112).
- In `docs/overhaul-ledger.md`: Update entries for removed wallpaper components.

- [ ] **Step 5: Commit**

```bash
rtk git add quickshell/bar/test-settings-ui.qml quickshell/bar/AGENTS.md AGENTS.md docs/overhaul-ledger.md
rtk git rm quickshell/bar/test-wallpaper-panel.qml
rtk git commit -m "test(settings): update test-settings-ui and drop obsolete wallpaper test"
```

---

### Task 9: Full System Verification

**Files:**
- None (verification only)

- [ ] **Step 1: Run all offline self-checks**

Run:
```bash
nix shell nixpkgs#shellcheck -c shellcheck -S warning -e SC1090 -P quickshell $(git ls-files '*.sh')
cd quickshell/bar
for t in icons grid notifications shelf settings-ui security-ui desktop scroll vm-service reorder-list greeter bar-modular; do
  qs -p "./test-$t.qml"
done
```
Expected: All tests PASS.

- [ ] **Step 2: Run nix flake check**

Run: `nix flake check`
Expected: Evaluates cleanly and builds `checks.hostMain`.
