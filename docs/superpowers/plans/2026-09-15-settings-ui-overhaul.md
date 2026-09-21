# Settings UI & Information Architecture Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul the mujō Settings UI: reorganize the 5-category Information Architecture, deduplicate redundant and misplaced settings, rebuild the search index with tag-based semantic matching, and redesign the visual presentation with elevated surface cards, top sub-tab bars, and tactile controls.

**Architecture:** Update QML category host pages (`WorkspacePage`, `HardwarePage`, `SecurityPage`), reorganize group components (`IdlePowerGroup`, `PreferencesGroup`, `PrivacyGroup`, `BarGroup`, `MotionGroup`), restructure `SearchIndex.js` with deduplicated keyword-tagged entries, enhance visual primitives (`MujoCard`, `SettingsPage`, `SettingsSearchResults`), and update the deterministic verification test suite `test-settings-ui.qml`.

**Tech Stack:** Quickshell, QML (Qt 6), JavaScript, NixOS / Wayland (`niri`).

**Spec:** [`docs/superpowers/specs/2026-09-15-settings-ui-overhaul-design.md`](file:///home/yurii/nixconf/docs/superpowers/specs/2026-09-15-settings-ui-overhaul-design.md)

## Global Constraints

- Never hardcode `"yurii"` — use `config.preferences.user.name` or `Quickshell.env("HOME")`.
- Read colors from `Theme.*` in QML — no arbitrary un-themed hex literals.
- All self-checks (`qs -p ./quickshell/bar/test-settings-ui.qml`) must pass deterministically.
- All shell commands must be prefixed with `rtk` when running supported CLI tools.

---

### Task 1: Deduplicate Controls & Clean Up Group Components

**Files:**
- Modify: `quickshell/bar/modules/settings/BarGroup.qml`
- Modify: `quickshell/bar/modules/settings/PreferencesGroup.qml`
- Modify: `quickshell/bar/modules/settings/IdlePowerGroup.qml`
- Modify: `quickshell/bar/modules/settings/PrivacyGroup.qml`

**Interfaces:**
- Consumes: `SettingsBus` (`idle.rules`, `idle.enabled`, `lock.enable`, `powerProfile`)
- Produces: Cleaned component groups without duplicate Bluetooth toggles, misplaced power governors, or duplicate lock toggles.

- [ ] **Step 1: Remove duplicate Bluetooth toggle from BarGroup.qml**
In `quickshell/bar/modules/settings/BarGroup.qml`, delete the duplicate `SettingRow { path: "bar.bluetooth.showDevice" }` inside the `selectedBarWidget === "network"` column layout (around line 859), leaving it strictly in the `selectedBarWidget === "bluetooth"` block.

- [ ] **Step 2: Move Hardware Power Profile from PreferencesGroup.qml to IdlePowerGroup.qml**
In `quickshell/bar/modules/settings/PreferencesGroup.qml`, remove the `MujoSettingRow` for "Hardware Power Profile" and the associated `powerProc` / `powerProfile` property.
In `quickshell/bar/modules/settings/IdlePowerGroup.qml`, add a CPU Hardware Power Profile (`power-profile`) control row inside the power management section.

- [ ] **Step 3: Consolidate Session Lock & Privacy in PrivacyGroup.qml**
In `quickshell/bar/modules/settings/PrivacyGroup.qml`, remove the redundant `Session Lock` card (which duplicated `IdlePowerGroup`), leaving `PrivacyGroup` focused purely on Local Activity Trail (`privacy.recentFiles`) and IP Geolocation fallback (`privacy.locationAccess`).

---

### Task 2: Reorganize Category Pages & Information Architecture

**Files:**
- Modify: `quickshell/bar/settings.qml`
- Modify: `quickshell/bar/modules/settings/WorkspacePage.qml`
- Modify: `quickshell/bar/modules/settings/HardwarePage.qml`
- Modify: `quickshell/bar/modules/settings/SecurityPage.qml`

**Interfaces:**
- Consumes: Group components (`NotificationsGroup`, `WeatherGroup`, `NetworkGroup`, `DisplaysGroup`, `IdlePowerGroup`, etc.)
- Produces: 5-Category unified layout where `Workspace` owns Notifications & Weather, `Hardware` owns Network (Mullvad) & Power, and `Security` is streamlined.

- [ ] **Step 1: Update WorkspacePage.qml with Notifications & Weather**
In `quickshell/bar/modules/settings/WorkspacePage.qml`, add `notifications` and `weather` to `sections`, `cardMap`, and instantiate `NotificationsGroup` and `WeatherGroup` in their own respective section components.

- [ ] **Step 2: Clean HardwarePage.qml (remove Weather, keep Network as Mullvad VPN)**
In `quickshell/bar/modules/settings/HardwarePage.qml`, remove `WeatherGroup` from `networkSection` so `networkSection` is purely `NetworkGroup`. Update `cardMap` and `aliases` accordingly.

- [ ] **Step 3: Streamline SecurityPage.qml (remove Notifications from Privacy)**
In `quickshell/bar/modules/settings/SecurityPage.qml`, update `privacySection` to contain `PersistenceGroup` and `PrivacyGroup` without `NotificationsGroup`. Update `cardMap` and `aliases`.

- [ ] **Step 4: Update settings.qml categories definition**
In `quickshell/bar/settings.qml`, update `categories` array to reflect the new `subs` and `keys` mapping:
  - `workspace`: `subs: [{ id: "bar" }, { id: "island" }, { id: "widgets" }, { id: "notifications" }, { id: "weather" }, { id: "shelf" }]`
  - `hardware`: `subs: [{ id: "displays" }, { id: "input" }, { id: "shortcuts" }, { id: "power" }, { id: "network" }, { id: "vm" }]`
  - `security`: `subs: [{ id: "integrity" }, { id: "trust" }, { id: "keyring" }, { id: "ai" }, { id: "persistence" }]`

---

### Task 3: Overhaul Search Index & Grouped Search Results UX

**Files:**
- Modify: `quickshell/bar/modules/settings/SearchIndex.js`
- Modify: `quickshell/bar/modules/settings/SettingsLayout.qml`
- Modify: `quickshell/bar/modules/settings/SettingsSearchResults.qml`

**Interfaces:**
- Consumes: `SearchIndex.entries`
- Produces: Deduplicated, tag-aware search matching and grouped search results with category path chips.

- [ ] **Step 1: Rewrite SearchIndex.js with deduplicated semantic entries and tags**
Reconstruct `quickshell/bar/modules/settings/SearchIndex.js` so each entry is unique and actionable with a `tags` array for query matching. Eliminate duplicate entries that route to the same card.

- [ ] **Step 2: Enhance scoring function in SettingsLayout.qml**
Update `score(e, q)` in `quickshell/bar/modules/settings/SettingsLayout.qml` to match against `e.title`, `e.tags`, `e.cat`, and `e.desc`.

- [ ] **Step 3: Update SettingsSearchResults.qml with category breadcrumbs & styling**
In `quickshell/bar/modules/settings/SettingsSearchResults.qml`, display category and sub-tab path chips (e.g. `Workspace › Notifications & DND`), enhance keyboard focus styling, and improve empty state guidance.

---

### Task 4: Visual Polish — Surface Cards & Sub-Tab Navigation Bar

**Files:**
- Modify: `quickshell/bar/components/MujoCard.qml`
- Modify: `quickshell/bar/modules/settings/SettingsPage.qml`
- Modify: `quickshell/bar/modules/settings/SettingsNavRow.qml`

**Interfaces:**
- Consumes: `Theme.*`, `Anim.*`
- Produces: Polished elevated surface cards, top sub-tab switcher, and crisp navigation row markers.

- [x] **Step 1: Elevate MujoCard.qml with surface background, subtle border and refined header**
In `quickshell/bar/components/MujoCard.qml`, add an elevated surface background (`Theme.surface`), subtle border (`Theme.border`), generous inner padding, and an icon/badge header layout.

- [x] **Step 2: Add Sub-Tab Segmented Bar in SettingsPage.qml**
In `quickshell/bar/modules/settings/SettingsPage.qml`, add a top `MujoSegmented` bar showing all sections of the current page, allowing instant tab switching directly in the content header.

- [x] **Step 3: Refine SettingsNavRow.qml and Sidebar styling**
Ensure active gutter indicator, font weights, and hover states are crisp and responsive.

---

### Task 5: Update & Verify Test Suite

**Files:**
- Modify: `quickshell/bar/test-settings-ui.qml`

**Interfaces:**
- Consumes: `SearchIndex.entries`, `SettingsLayout`, `SystemPage`, `AppearancePage`, `WorkspacePage`, `HardwarePage`, `SecurityPage`
- Produces: 100% passing automated test run verifying all routing, aliases, sub-tabs, store bindings, and card anchors.

- [x] **Step 1: Update test-settings-ui.qml with new sub-tabs and card anchors**
Update category and sub-tab assertions in `quickshell/bar/test-settings-ui.qml` to match the new Information Architecture.

- [x] **Step 2: Run test-settings-ui.qml and verify PASS**
Run: `rtk qs -p ./quickshell/bar/test-settings-ui.qml`
Expected: `PASS settings UI: IA routing, aliases, store bindings, light/dark mode, schedule, and search card anchors verified` with 0 failures.

- [x] **Step 3: Commit all changes**
```bash
git add quickshell/bar/ test-settings-ui.qml docs/superpowers/
git commit -m "feat(settings): overhaul UI, information architecture, and search indexing"
```
