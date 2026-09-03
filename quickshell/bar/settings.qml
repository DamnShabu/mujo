//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import Quickshell
import "./theme"
import "./modules/settings"
import "./modules/settings/SearchIndex.js" as SearchIndex

// mujō (無常) — Desktop Settings.
// 7-Category Information Architecture: System, Appearance, Workspace, Wallpapers,
// Intelligence, Hardware, Security.
// Every category is a consolidated SettingsPage composed of reusable MujoCards.
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

        // ── Consolidated Category Pages ───────────────────────────────────────
        Component { id: systemComp;       SystemPage {} }
        Component { id: appearanceComp;   AppearancePage {} }
        Component { id: workspaceComp;    WorkspacePage {} }
        Component { id: wallpapersComp;   WallpapersPage {} }
        Component { id: intelligenceComp; IntelligencePage {} }
        Component { id: hardwareComp;     HardwarePage {} }
        Component { id: securityComp;     SecurityPage {} }

        SettingsLayout {
            anchors.fill: parent

            // ── 7-Category Unified Information Architecture ───────────────────
            categories: [
                {
                    key: "system", label: "System", icon: "tune", brand: "system",
                    subtitle: "Host, rebuild, health, preferences & apps",
                    page: systemComp, badge: 4,
                    keys: ["system", "overview", "health", "general", "applications", "host", "rebuild", "gc", "sentinel"]
                },
                {
                    key: "appearance", label: "Appearance", icon: "palette", brand: "appearance",
                    subtitle: "Theme presets, accent colors & motion",
                    page: appearanceComp, badge: 2,
                    keys: ["appearance", "theme", "colors", "accent", "transparency", "motion", "animations"]
                },
                {
                    key: "workspace", label: "Workspace", icon: "dock_to_bottom", brand: "desktop",
                    subtitle: "Bar layout, dynamic island, widgets & shelf",
                    page: workspaceComp, badge: 4,
                    keys: ["workspace", "bar", "island", "widgets", "desktop", "shelf"]
                },
                {
                    key: "wallpapers", label: "Wallpapers", icon: "wallpaper", brand: "wallpaper",
                    subtitle: "Local catalog, Wallhaven & Wallpaper Engine",
                    page: wallpapersComp, badge: 1,
                    keys: ["wallpapers", "wallpaper", "wallhaven", "wallpaperengine", "effects", "parallax"]
                },
                {
                    key: "intelligence", label: "Intelligence", icon: "psychology", brand: "ai",
                    subtitle: "Coding agents, alerts, VPN & weather",
                    page: intelligenceComp, badge: 4,
                    keys: ["intelligence", "ai", "notifications", "weather", "network", "vpn", "mullvad", "dnd"]
                },
                {
                    key: "hardware", label: "Hardware", icon: "monitor", brand: "display",
                    subtitle: "Displays, input, power, shortcuts & VMs",
                    page: hardwareComp, badge: 5,
                    keys: ["hardware", "display", "displays", "devices", "input", "keyboard", "mouse", "touchpad", "shortcuts", "vm", "machines", "idle", "power", "screen"]
                },
                {
                    key: "security", label: "Security", icon: "shield", brand: "security",
                    subtitle: "Verified boot, LUKS2 vault, trust, persistence & privacy",
                    page: securityComp, badge: 5,
                    keys: ["security", "vault", "keyring", "trust", "persistence", "privacy", "tpm", "boot"]
                }
            ]

            searchIndex: SearchIndex.entries
        }
    }
}
