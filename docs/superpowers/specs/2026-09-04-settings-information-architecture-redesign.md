# Settings Information Architecture Redesign: 5-Category Navigation with Sub-Category Tabs

## 1. Overview & Goals

The mujō Settings application is being redesigned to replace the legacy 7-category, vertically unconstrained card stack with a modern **5-Category Information Architecture** featuring **Segmented Sub-Category Tabs**.

### Primary Goals:
- **Maximum 5 Top-Level Categories:** Reduce cognitive load by consolidating into 5 distinct, well-defined domains in the sidebar rail.
- **Direct Sub-Category Access (Max 5 per category):** Every subsystem is accessible in 1 click via horizontal segmented tab pills (`MujoSegmented`) under the category header.
- **Zero Content Clutter:** Eliminate long vertical scrolling lists by presenting focused sub-pages per sub-category.
- **Deep Linking & Alias Routing:** Full backward compatibility for omni-search (`/`, `Ctrl+F`), dashboard links, and CLI verbs (`mujo settings wallpaper`, `mujo settings vpn`, `mujo settings ai`, etc.).
- **Rigorous Verification:** Update the self-check suite (`test-settings-ui.qml`) to validate all routes, aliases, and search card anchors.

---

## 2. 5-Category Information Architecture

```
Settings
├── 1. System (system)
│   ├── Host & Rebuild (rebuild)       → NixosHostGroup
│   ├── Health & Storage (health)      → HealthGroup
│   ├── Preferences (preferences)      → PreferencesGroup
│   └── Applications (apps)            → ApplicationsGroup
│
├── 2. Appearance (appearance)
│   ├── Themes & Colors (themes)       → ThemeGroup
│   ├── Wallpapers (wallpapers)        → WallpaperBrowseGroup (Library, Wallhaven, WPE)
│   ├── Wallpaper Effects (effects)    → WallpaperEffectsGroup
│   └── Motion Dynamics (motion)       → MotionGroup
│
├── 3. Workspace (workspace)
│   ├── Desktop Bar (bar)              → BarGroup
│   ├── Dynamic Island (island)        → IslandGroup
│   ├── Overlay Widgets (widgets)      → WidgetsGroup
│   └── Shelf (shelf)                  → ShelfGroup
│
├── 4. Hardware (hardware)
│   ├── Displays (displays)            → DisplaysGroup
│   ├── Input & Keys (input)           → InputGroup & ShortcutsGroup
│   ├── Network & VPN (network)        → NetworkGroup & WeatherGroup
│   ├── Power & Sleep (power)          → IdlePowerGroup
│   └── Virtual Machines (vm)          → VmGroup
│
└── 5. Security & AI (security)
    ├── System Integrity (integrity)   → SecurityGroup (Boot, TPM, Vault, Hardening)
    ├── AI Assistants (ai)             → AiGroup (Agent CLIs, API Providers, Keyring)
    ├── Trust & Sandbox (trust)        → ApplicationsTrustTab (MicroVM, Native, Sandbox)
    ├── Credentials (keyring)          → KeyringGroup (Secret Service keys)
    └── Privacy & Alerts (privacy)     → PrivacyGroup, PersistenceGroup & NotificationsGroup
```

---

## 3. Detailed Component & Routing Matrix

### 1. System (`key: "system"`, icon: `"tune"`, brand: `"system"`)
- **Subtitle:** *Host configuration, rebuilds, health sentinel, storage cleaner, preferences & apps.*
- **Sub-Tabs:**
  1. `Host & Rebuild` (`rebuild`): NixOS generation history, rebuild/switch with pkexec, flake status, local overrides.
  2. `Health & Storage` (`health`): Process sentinel, anomaly tracker, zombie reaper, storage cleaner, memory/ZRAM compaction.
  3. `Preferences` (`preferences`): Default applications (MIME), Hostname & Timezone, CPU power profile, sound chimes, clipboard history (cliphist).
  4. `Applications` (`apps`): Companion integrations (Discord, Obsidian, Steam, VS Code, Spotify), Flatpaks & permissions, launcher pins.
- **Routing Aliases:** `["system", "overview", "health", "general", "applications", "host", "rebuild", "gc", "sentinel", "preferences", "apps"]`

### 2. Appearance (`key: "appearance"`, icon: `"palette"`, brand: `"appearance"`)
- **Subtitle:** *Theme presets, accent colors, wallpaper catalog, live engines & motion dynamics.*
- **Sub-Tabs:**
  1. `Themes & Colors` (`themes`): Theme presets (Crimson, Catppuccin, Ayu, Dracula, Nord, Gruvbox...), accent swatches & custom hex, glass opacity.
  2. `Wallpapers` (`wallpapers`): Curated local high-res library, Wallhaven online explorer, Wallpaper Engine Steam Workshop catalog.
  3. `Wallpaper Effects` (`effects`): Cursor parallax & depth motion, letterbox background fill color, live wallpaper performance & FPS.
  4. `Motion Dynamics` (`motion`): Physics profiles (Minimal/Balanced/Expressive), Interactive Playground, granular transitions, accessibility & low-power.
- **Routing Aliases:** `["appearance", "theme", "colors", "accent", "transparency", "motion", "animations", "wallpapers", "wallpaper", "wallhaven", "wallpaperengine", "effects", "parallax"]`

### 3. Workspace (`key: "workspace"`, icon: `"dock_to_bottom"`, brand: `"desktop"`)
- **Subtitle:** *Desktop bar layout, dynamic island notch, overlay widgets & staging shelf.*
- **Sub-Tabs:**
  1. `Desktop Bar` (`bar`): Edge attachment, height, auto-hide, right cluster module ordering, workspace numerals/gliders, clock format, launcher icon, active window pill.
  2. `Dynamic Island` (`island`): Floating notch modules, geometry & surface, auto-expand alerts on notifications & media.
  3. `Overlay Widgets` (`widgets`): Desktop overlay widgets placement, global glassmorphism/shadows, Sticky Notes color themes, Cava audio visualizer.
  4. `Shelf` (`shelf`): Edge file staging drop zone & buffer.
- **Routing Aliases:** `["workspace", "bar", "island", "widgets", "desktop", "shelf"]`

### 4. Hardware (`key: "hardware"`, icon: `"monitor"`, brand: `"display"`)
- **Subtitle:** *Displays, input devices, keyboard shortcuts, network VPN, power & virtual machines.*
- **Sub-Tabs:**
  1. `Displays` (`displays`): Visual drag-and-drop arrangement, resolution, refresh rate (Hz), HiDPI scaling.
  2. `Input & Keys` (`input`): Keyboard repeat & layout, mouse/touchpad acceleration & natural scrolling, Niri shortcuts matrix.
  3. `Network & VPN` (`network`): Mullvad WireGuard VPN status & relays, keyring credentials, Open-Meteo weather telemetry.
  4. `Power & Sleep` (`power`): Screen dim, display turn-off, sleep timers, lock screen grace period.
  5. `Virtual Machines` (`vm`): KVM/SPICE virtual machines lab, guest catalog provisioning.
- **Routing Aliases:** `["hardware", "display", "displays", "devices", "input", "keyboard", "mouse", "touchpad", "shortcuts", "vm", "machines", "idle", "power", "screen", "network", "vpn", "mullvad", "weather"]`

### 5. Security & AI (`key: "security"`, icon: `"shield"`, brand: `"security"`)
- **Subtitle:** *Verified boot, AI assistants, progressive trust sandbox, credentials, privacy & alerts.*
- **Sub-Tabs:**
  1. `System Integrity` (`integrity`): UEFI Verified Boot, TPM 2.0 PCR state, Host hardening / Kernel lockdown, LUKS2 encrypted vault.
  2. `AI Assistants` (`ai`): Coding assistant CLI engine (Claude Code, opencode, Antigravity, Codex, Gemini CLI, Pi), OpenAI API endpoint & model, keyring credentials, safety guardrails.
  3. `Trust & Sandbox` (`trust`): Progressive trust & isolation tiers (Native, Sandbox, MicroVM, Blocked).
  4. `Credentials` (`keyring`): Secret Service stored credentials & API tokens manager.
  5. `Privacy & Alerts` (`privacy`): Impermanence persistence paths, activity history trail, Do Not Disturb, sound alerts, per-app mute rules.
- **Routing Aliases:** `["security", "vault", "keyring", "trust", "persistence", "privacy", "tpm", "boot", "ai", "intelligence", "notifications", "dnd", "credentials", "integrity"]`

---

## 4. UI/UX Interaction & Technical Design

### A. Sub-Category Switching (`MujoSegmented`)
Each category page renders a top `MujoSegmented` tab bar:
- The active sub-tab state is held as a reactive property (e.g. `property string subTab: "rebuild"`).
- Switching sub-tabs displays the corresponding sub-category component view.
- Category pages with standard `MujoCard` items use a dedicated scrolling container (`MujoFlickable`) per sub-tab, ensuring scroll positions remain independent and don't jank.
- Complex views like Wallpaper Browsers (`WallpaperBrowseGroup`) retain their full-height viewport management without double flickables.

### B. Deep Linking & Omni-Search Routing
When `SettingsLayout.route(key, card)` is called:
1. `SettingsLayout` matches `key` against category keys and alias lists.
2. The category page exposes a `revealSubTab(subTabKey, cardTitle)` method or parses `pendingCard`.
3. If `key` is an alias for a specific sub-tab (e.g. `vpn` or `weather` under Hardware, `wallhaven` under Appearance, `ai` under Security & AI), the category automatically switches its `subTab` to that sub-category and then scrolls smoothly to the target card.

### C. Search Index Synchronization (`SearchIndex.js`)
All search index entries are categorized under the 5 canonical category labels (`System`, `Appearance`, `Workspace`, `Hardware`, `Security & AI`) and carry accurate `key` routing aliases and `card` anchors.

---

## 5. Verification Plan

1. **Self-Check Test Suite (`test-settings-ui.qml`):**
   - Run `qs -p ./quickshell/bar/test-settings-ui.qml`
   - Assert all 5 top-level categories route properly.
   - Assert all sub-category aliases route to their correct parent category and trigger the appropriate sub-tab.
   - Assert every single `SearchIndex.entries` item resolves to an existing `MujoCard` or tab on the target page.
2. **Interactive Sandbox Testing:**
   - Use the graphical sandbox MCP tools to verify the UI visually.
   - Verify keyboard navigation (Up/Down in sidebar, Tab/Arrow keys in segmented pills).
   - Test search queries (`vpn`, `theme`, `displays`, `ai`, `cleaner`) to ensure seamless deep-linking to the exact sub-tab and card.
