//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import Quickshell
import "./theme"
import "./modules/settings"
import "./modules/bar"

// mujō (無常) — Desktop Settings.
// The window is only a frame. The split view, omni-search, routing and
// crossfades live in SettingsLayout; everything below is data: five sidebar
// categories and the search index.
//
// A category is either consolidated (`page:` — a SettingsPage of MujoCards) or
// still split across the legacy per-domain panels (`panels:` — shown on an
// in-page chip rail). Migrating a category swaps its `panels` for a `page`;
// nothing else changes here.
ShellRoot {
    FloatingWindow {
        id: win
        title: "mujō — Settings"
        implicitWidth: 1120
        implicitHeight: 740
        color: Theme.bg

        // Quit whenever the window closes so no headless process lingers
        property bool _shown: false
        onVisibleChanged: {
            if (visible) _shown = true
            else if (_shown) Qt.quit()
        }

        // ── Domain panels ────────────────────────────────────────────────────
        Component { id: overviewComp;      OverviewPanel {} }
        Component { id: generalComp;       GeneralPanel {} }
        Component { id: appearanceComp;    AppearancePanel {} }
        Component { id: animationsComp;    AnimationsPanel {} }
        Component { id: wallpaperComp;     WallpaperPanel {} }
        Component { id: desktopComp;       DesktopPanel {} }
        Component { id: islandComp;        IslandPanel {} }
        Component { id: weatherComp;       WeatherPanel {} }
        Component { id: aiComp;            AiPanel {} }
        Component { id: notificationsComp; NotificationsPanel {} }
        Component { id: networkComp;       NetworkPanel {} }
        Component { id: persistenceComp;   PersistencePanel {} }
        Component { id: healthComp;        HealthPanel {} }
        Component { id: systemComp;        SystemPanel {} }
        Component { id: applicationsComp;  ApplicationsPanel {} }

        // Consolidated category pages (SettingsPage + cards)
        Component { id: hardwareComp;      HardwarePage {} }

        SettingsLayout {
            anchors.fill: parent

            // ── Five categories, two levels deep ─────────────────────────────
            categories: [
                {
                    key: "system", label: "System", icon: "tune", brand: "system",
                    subtitle: "Host, rebuild, storage & health",
                    panels: [
                        { key: "overview",     label: "Overview",     comp: overviewComp },
                        { key: "system",       label: "NixOS",        comp: systemComp },
                        { key: "health",       label: "Health",       comp: healthComp },
                        { key: "general",      label: "Preferences",  comp: generalComp },
                        { key: "persistence",  label: "Persistence",  comp: persistenceComp },
                        { key: "applications", label: "Applications", comp: applicationsComp }
                    ]
                },
                {
                    key: "appearance", label: "Appearance", icon: "palette", brand: "appearance",
                    subtitle: "Theme, motion & bar",
                    panels: [
                        { key: "appearance", label: "Theme & Bar", comp: appearanceComp },
                        { key: "animations", label: "Motion",      comp: animationsComp },
                        { key: "island",     label: "Island",      comp: islandComp }
                    ]
                },
                {
                    key: "desktop", label: "Desktop", icon: "wallpaper", brand: "desktop",
                    subtitle: "Wallpaper, widgets & canvas",
                    panels: [
                        { key: "wallpaper", label: "Wallpaper", comp: wallpaperComp },
                        { key: "desktop",   label: "Widgets",   comp: desktopComp }
                    ]
                },
                {
                    key: "intelligence", label: "Intelligence", icon: "psychology", brand: "ai",
                    subtitle: "AI, alerts & network",
                    panels: [
                        { key: "ai",            label: "AI",            comp: aiComp },
                        { key: "notifications", label: "Notifications", comp: notificationsComp },
                        { key: "weather",       label: "Weather",       comp: weatherComp },
                        { key: "network",       label: "Network",       comp: networkComp }
                    ]
                },
                {
                    key: "hardware", label: "Hardware", icon: "monitor", brand: "display",
                    subtitle: "Displays, input, machines & keys",
                    // Consolidated: one page of cards. `keys` keeps the old
                    // panel keys routable, so `mujo settings vm`, Overview's
                    // cards and the search index all still land here.
                    page: hardwareComp, badge: 7,
                    keys: ["display", "devices", "shortcuts", "vm", "keyring", "security", "vault", "idle", "lock"]
                }
            ]

            // ── Omni-search index ────────────────────────────────────────────
            // `key` is a panel key; SettingsLayout.route() resolves it to the
            // owning category, so entries survive a category being consolidated.
            searchIndex: [
                // System
                { title: "System status overview", desc: "Live vitals, system metrics, hardware telemetry", cat: "System", key: "overview" },
                { title: "Quick controls",      desc: "Live toggles for Wi-Fi, Bluetooth, DND, VPN", cat: "System", key: "overview" },
                { title: "Active media playback",desc: "Currently playing track and MPRIS controls", cat: "System", key: "overview" },
                { title: "NixOS rebuild switch",desc: "Apply and switch host configuration with pkexec escalation", cat: "System", key: "system" },
                { title: "Generation history",  desc: "Inspect current and past bootable system generations", cat: "System", key: "system" },
                { title: "System overrides",    desc: "Local module drop-in overrides and flake inspect", cat: "System", key: "system" },
                { title: "System health & optimizer", desc: "Live process sentinel, runaway killer, storage cleaner", cat: "System", key: "health" },
                { title: "Problematic processes", desc: "View and manage runaway tasks, memory hogs, zombies, and terminated processes", cat: "System", key: "health" },
                { title: "Process sentinel & killer", desc: "Freeze, renice, or terminate runaway CPU/RAM tasks and zombies", cat: "System", key: "health" },
                { title: "Storage & cache cleaner", desc: "Vacuum journal logs, clean Nix store, purge thumbnails and trash", cat: "System", key: "health" },
                { title: "General preferences", desc: "Hostname, timezone, locale, store hardlinking", cat: "System", key: "general" },
                { title: "Default applications",desc: "MIME handlers for browser, editor, terminal, file manager", cat: "System", key: "general" },
                { title: "Clipboard history",   desc: "Max clipboard clips, sensitive filter, image cache", cat: "System", key: "general" },

                // Personalization
                { title: "Theme preset",        desc: "Crimson, Blood Moon, Catppuccin, Ayu, Dracula, Nord, Gruvbox…", cat: "Personalization", key: "appearance" },
                { title: "Accent color override",desc: "Custom hex or curated palette accent color", cat: "Personalization", key: "appearance" },
                { title: "Surface opacity",     desc: "Translucent glass alpha and blur controls", cat: "Personalization", key: "appearance" },
                { title: "Bar layout & modules",desc: "Bar position, height, margin, and right cluster ordering", cat: "Personalization", key: "appearance" },
                { title: "Bar widget styles",   desc: "Workspaces numerals, gliders, clock format, volume percent, battery modes", cat: "Personalization", key: "appearance" },
                { title: "Workspaces glider & numerals", desc: "Morphic glider, roman numerals, dots, window presence dots", cat: "Personalization", key: "appearance" },
                { title: "Animation intensity", desc: "Minimal, Balanced, or Expressive motion profile", cat: "Personalization", key: "animations" },
                { title: "Ambient motion & breathing", desc: "Living background flow, breathing, particle fields", cat: "Personalization", key: "animations" },
                { title: "Live motion preview", desc: "Interactive showcase demonstrating physics and spring curves", cat: "Personalization", key: "animations" },
                { title: "Page transitions",    desc: "Fluid crossfade and spatial transitions between pages", cat: "Personalization", key: "animations" },
                { title: "Reduced motion override", desc: "Accessibility preference eliminating spatial and continuous motion", cat: "Personalization", key: "animations" },
                { title: "Performance mode",    desc: "Reduce GPU/rendering load on low-power hardware", cat: "Personalization", key: "animations" },
                { title: "Wallpaper library",   desc: "Apply from local curated wallpaper collection", cat: "Personalization", key: "wallpaper" },
                { title: "Wallhaven browser",   desc: "Search, preview, and download wallpapers online", cat: "Personalization", key: "wallpaper" },
                { title: "Wallpaper Engine browser", desc: "Browse Steam Workshop Wallpaper Engine (431960) and installed live projects", cat: "Personalization", key: "wallpaper" },
                { title: "Wallpaper Engine performance", desc: "Live wallpaper FPS limit, audio automute, and sound volume", cat: "Personalization", key: "wallpaper" },
                { title: "Cursor parallax",     desc: "Dynamic wallpaper pan and depth motion on mouse move", cat: "Personalization", key: "wallpaper" },
                { title: "Desktop widgets",     desc: "Clock, system telemetry, weather, notes, photo, media desktop overlays", cat: "Personalization", key: "desktop" },
                { title: "Widget styles & glassmorphism", desc: "Glass opacity, corner radius, drop shadows, border glow", cat: "Personalization", key: "desktop" },
                { title: "Sticky notes colors", desc: "Slate, yellow, rose, emerald, dark color themes and font sizes", cat: "Personalization", key: "desktop" },
                { title: "Now playing vinyl style", desc: "Rotating vinyl record player, album art, playback controls", cat: "Personalization", key: "desktop" },
                { title: "Audio visualizer",    desc: "Cava spectrum visualizer style, color, and responsiveness", cat: "Personalization", key: "desktop" },
                { title: "Shelf drop zone",     desc: "Staging drawer for files and dragging items", cat: "Personalization", key: "desktop" },
                { title: "Dynamic Island",      desc: "Status notch: modules, geometry, animations, and auto-expand", cat: "Personalization", key: "island" },

                // Intelligence & Network
                { title: "AI provider & model", desc: "Ollama local, OpenAI, Claude, model name and base URL", cat: "Intelligence", key: "ai" },
                { title: "AI API credentials",  desc: "Keyring token storage and endpoint authentication", cat: "Intelligence", key: "ai" },
                { title: "AI privacy guards",   desc: "Context sharing, crash data opt-in, action confirmation", cat: "Intelligence", key: "ai" },
                { title: "Do Not Disturb",      desc: "Silence notification banners and toast alerts", cat: "Intelligence", key: "notifications" },
                { title: "Notification position",desc: "Screen corner gravity and toast timeout", cat: "Intelligence", key: "notifications" },
                { title: "Per-app notification muting", desc: "Selectively mute applications", cat: "Intelligence", key: "notifications" },
                { title: "Weather location",    desc: "City auto-detect, temperature units (°C/°F), refresh rate", cat: "Intelligence", key: "weather" },
                { title: "Mullvad VPN",         desc: "WireGuard connection, relay location, and boot auto-connect", cat: "Intelligence", key: "network" },
                { title: "Network interfaces",  desc: "Wi-Fi, Ethernet, IP address, gateway telemetry", cat: "Intelligence", key: "network" },

                // Hardware
                { title: "Display resolution & Hz", desc: "Resolution, refresh rate, and HiDPI scaling per screen", cat: "Hardware", key: "display" },
                { title: "Visual monitor layout", desc: "Arrangement, orientation, and primary screen setup", cat: "Hardware", key: "display" },
                { title: "Idle & power timers", desc: "Dim screen, display turn-off, lock screen, and suspend", cat: "Hardware", key: "display" },
                { title: "Keyboard repeat & delay", desc: "Key repeat rate and initial delay sensitivity", cat: "Hardware", key: "devices" },
                { title: "Keyboard layout",     desc: "XKB keymap layout and language variants", cat: "Hardware", key: "devices" },
                { title: "Pointer & Touchpad",  desc: "Mouse acceleration profile, natural scrolling, tap-to-click", cat: "Hardware", key: "devices" },
                { title: "Keyboard shortcuts",  desc: "Interactive searchable matrix of Niri window bindings", cat: "Hardware", key: "shortcuts" },
                { title: "Virtual machines & lab", desc: "Launch Windows, Ubuntu, Fedora, Arch in KVM with SPICE visual display", cat: "Hardware", key: "vm" },
                { title: "Deploy operating system", desc: "One-click download and launch Windows 11, macOS, Alpine, Debian", cat: "Hardware", key: "vm" },
                { title: "SPICE visual server", desc: "Zero-latency remote-viewer display with shared clipboard and auto-resizing", cat: "Hardware", key: "vm" },
                { title: "Custom ISO virtual machine", desc: "Create accelerated QEMU virtual machine from local ISO file", cat: "Hardware", key: "vm" },

                // Storage & Security
                { title: "Security & Trust architecture", desc: "Verified boot, TPM 2.0, LUKS2 encrypted vault, progressive trust", cat: "Security", key: "security" },
                { title: "Encrypted Storage Vault", desc: "Unlock / lock /persist/secure/mujo-vault.luks container", cat: "Security", key: "vault" },
                { title: "Keyring vault",       desc: "Secure credentials, secret specs, and reveal tokens", cat: "Security", key: "keyring" },
                { title: "Impermanence storage",desc: "Persistent directories and files surviving btrfs boot wipe", cat: "Security", key: "persistence" },
                { title: "Integrations & Apps", desc: "Discord, Obsidian, Claude, Steam, Flatpaks, sandboxing", cat: "Security", key: "applications" }
            ]
        }
    }
}
