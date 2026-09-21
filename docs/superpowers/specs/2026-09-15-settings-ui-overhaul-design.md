# mujō Settings UI & Information Architecture Overhaul Design Spec

**Date**: 2026-09-15  
**Status**: Approved (In Design)  
**Target System**: mujō Desktop Shell (`quickshell/bar`)

---

## 1. Executive Summary & Goals

The mujō Settings application (`quickshell/bar/settings.qml`) provides configuration management for the host NixOS system, desktop chrome, hardware devices, security vault, and AI assistants. 

This overhaul addresses four core user pain points:
1. **Search Redundancy**: Resolving duplicate search results where 5–8 entries led to the identical destination card.
2. **Duplicate & Misplaced Options**: Eliminating redundant settings (e.g. Session Lock in two places, Recent Apps in two places, duplicate Bluetooth toggles) and moving misplaced features to their intuitive domains (Weather & Notifications to Workspace; CPU Power Governor to Hardware Power).
3. **Placeholder & Dead Toggles**: Streamlining granular micro-toggles into clean, actionable control groups.
4. **Visual & Interaction Polish**: Replacing monotonous flat hairline rows with elevated surface cards, tactile controls, breadcrumb/sub-tab navigation, and distinct status badges.

---

## 2. 5-Category Information Architecture

The 5-category structure is reorganized so every setting lives in an intuitive, logical domain:

```
mujō Settings
├── 1. System (key: "system", icon: "tune", brand: "system")
│   ├── Host & Rebuild        (id: "rebuild")     -> NixOS Generation & Store, Flake Status, Switch/Rebuild Logs, Local Overrides
│   ├── Health & Storage      (id: "health")      -> Sentinel Process Tracker, Zombie Reaper, Storage Reclamation, ZRAM Compaction
│   ├── Preferences           (id: "preferences") -> Hostname, Timezone, Default Applications (XDG MIME), Clipboard History
│   └── Applications          (id: "apps")        -> Desktop Integrations, Flatpak Package Permissions & Flatseal, Pinned Favorites
│
├── 2. Appearance (key: "appearance", icon: "palette", brand: "appearance")
│   ├── Themes & Colors       (id: "themes")      -> Appearance Mode, Day/Night Solar Schedule, 34 Palette Accent Swatches, Surface Opacity
│   ├── Wallpapers            (id: "wallpapers")  -> Local Library, Wallhaven Online Browser, Wallpaper Engine Steam Workshop
│   ├── Wallpaper Effects     (id: "effects")     -> Parallax Depth, Background Fill Color, Engine FPS & Volume Limits
│   └── Motion Dynamics       (id: "motion")      -> Master Animation Engine, Intensity Profiles, Reduced Motion, Interactive Playground
│
├── 3. Workspace (key: "workspace", icon: "dock_to_bottom", brand: "desktop")
│   ├── Desktop Bar           (id: "bar")         -> Bar Layout & Geometry, Density, 3-Zone Slot Canvas Builder, Widget Customizer
│   ├── Dynamic Island        (id: "island")      -> Island Cluster Geometry, Modules & Ordering, Auto-Expand Durations & Alerts
│   ├── Desktop Widgets       (id: "widgets")     -> Overlay Canvas Edit Mode, Glassmorphism & Shadows, Per-Widget Customization
│   ├── Notifications & DND   (id: "notifications")-> Do Not Disturb, Toast Dismiss Timeout, Gravity Corner, Audio Chimes, Per-App Rules, Test Lab
│   ├── Weather & Telemetry   (id: "weather")     -> Current Atmospheric Conditions, 5-Day Forecast, Geocoding City Search, Auto-IP, Units
│   └── Shelf                 (id: "shelf")       -> Screen-Edge Staging Drop Zone, Strip Length, Persistence on Restart
│
├── 4. Hardware (key: "hardware", icon: "monitor", brand: "display")
│   ├── Displays              (id: "displays")    -> Multi-Monitor Arrangement Canvas, Resolution, Refresh Rate (Hz), HiDPI Scaling
│   ├── Input & Keys          (id: "input")       -> Keyboard Layout, Repeat Rate/Delay, Pointer Acceleration, Touchpad Gestures
│   ├── Niri Shortcuts        (id: "shortcuts")   -> Interactive Keybinding Matrix Parsed from Compositor Configuration
│   ├── Power & Sleep         (id: "power")       -> CPU Hardware Power Profile (Governor), Idle Sleep Rules, Display Off, Session Lock
│   ├── Network & VPN         (id: "network")     -> Mullvad WireGuard Tunnel Status, Keyring Credentials, Exit Node Relays
│   └── Virtual Machines      (id: "vm")          -> KVM Hypervisor Stats, Guest OS Catalog Deployment, Custom ISO Provisioning
│
└── 5. Security & Privacy (key: "security", icon: "shield", brand: "security")
    ├── System Integrity      (id: "integrity")   -> UEFI Secure Boot Status, TPM 2.0 PCRs, Kernel Lockdown, LUKS2 Vault Unlocking
    ├── Trust & Sandbox       (id: "trust")       -> Progressive Trust Engine Risk Tiers, Application Quarantine, Flatpak Narrowing
    ├── Credentials           (id: "keyring")     -> Gnome Keyring Secret Service Manager, Add/Remove Credentials, Token Reveal
    ├── AI Assistants         (id: "ai")          -> Coding Assistant CLI Selector, Ollama / OpenAI API Endpoints, Privacy Guardrails
    └── Persistence           (id: "persistence") -> Btrfs Impermanence Managed Bindings (/persist), User & System Directories
```

---

## 3. Deduplication & Cleanup Matrix

| Item | Problem | Resolution |
|---|---|---|
| **Lock Screen** | `lock.enable` in Hardware Power; `security.lockOnSuspend` in Security Privacy | Consolidated into `Hardware -> Power & Sleep` under a unified **Session Lock & Timers** section. |
| **Power Profile** | CPU Governor in `System -> Preferences` (`powerProfile`) | Moved into `Hardware -> Power & Sleep` directly above idle timers. |
| **Activity History** | `apps.recent` cleared in `ApplicationsLauncherTab`; `mujo privacy clear-recent` in `PrivacyGroup` | Consolidated in `System -> Applications -> Launcher` with single toggle and clear action. |
| **Bluetooth Toggle** | Duplicate `bar.bluetooth.showDevice` inside `network` and `bluetooth` widget blocks | Removed duplicate from `network` block in `BarGroup.qml`. |
| **Weather** | Mounted in `Hardware -> Network & VPN` under Mullvad | Relocated to `Workspace -> Weather & Telemetry` as a primary workspace section. |
| **Notifications** | Mounted in `Security & AI -> Privacy & Alerts` | Relocated to `Workspace -> Notifications & DND` as a primary workspace section. |
| **Motion Domains** | 5 separate micro-toggles with vague distinctions | Organized into **Master Engine & Intensity**, **Motion Domains** (Transitions, Tactile, Ambient), and **Accessibility** (Reduced Motion, Low-Power Mode). |

---

## 4. Search Indexing & Query Architecture

### 4.1. Index Schema
`SearchIndex.js` is structured so each entry represents a distinct functional capability:
```javascript
{
    title: "CPU Power Profile",
    desc: "Energy performance scaling governor (Performance, Balanced, Power Saver)",
    cat: "Hardware",
    key: "power",
    card: "Hardware Power Profile & Governor",
    tags: ["governor", "battery", "performance", "energy", "cpu", "fan"]
}
```

### 4.2. Semantic Matching & Tag Search
- Scoring algorithm checks `title` (prefix = 100, substring = 80), `tags` (match = 70), `cat` (match = 60), and `desc` (match = 40).
- Grouped presentation renders results with hierarchical path chips (e.g. `Workspace › Notifications & DND`).
- Direct navigation lands on the exact tab and triggers `scrollToCard(entry.card)`.

---

## 5. Visual & Interaction Design

### 5.1. Elevated Card Surfaces (`MujoCard.qml`)
- Background: `Theme.surface` with smooth `Theme.radiusMd` (10px) corners.
- Border: 1px subtle `Theme.border` / `Theme.borderInteractive` with animated hover depth.
- Header: Category/Section icon with title, status tags (`NIXOS`, `ACTIVE`, `SECURE`, `LOCKED`), and quick header actions.
- Inner rows: Clean spacing with soft hover scan-bands (`Theme.surfaceHover`) and aligned control slots.

### 5.2. Category Sub-Tab Navigation Bar
- At the top of each category page (`SettingsPage.qml`), render a modern segmented pill bar (`MujoSegmented`) for direct sub-category switching.
- Allows rapid switching between sub-tabs with fluid morphic glider animations.

### 5.3. Tactile Controls & Typography
- **Segmented pickers**: Clear active states, animated sliding focus pill.
- **Sliders**: Persistent monospace numeric indicators with units (`px`, `%`, `s`, `ms`).
- **Toggles**: Smooth elastic slide with theme accent indicator.
- **Action Buttons**: Distinct visual hierarchy (Primary accent, neutral ghost, destructive danger).

---

## 6. Testing & Validation Plan

1. **Deterministic Test Suite (`test-settings-ui.qml`)**:
   - Assert all 5 categories resolve correctly.
   - Assert every sub-tab ID matches its page's declared `tabIds`.
   - Assert every entry in `SearchIndex.js` routes to a valid category and existing card anchor.
   - Assert all store-backed settings (toggles, sliders, segmented, text) read and write `SettingsBus`.
   - Run via `qs -p ./quickshell/bar/test-settings-ui.qml` and ensure 0 failures.
2. **Offline Linting & Verification**:
   - Run `nix shell nixpkgs#shellcheck` on shell integration scripts.
   - Run `nix flake check` to ensure host flake evaluation remains green.
3. **Visual Inspection**:
   - Verify UI rendering, animations, sub-tab switching, and search functionality.
