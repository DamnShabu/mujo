//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import Quickshell
import "./theme"
import "./modules/settings"
import "./modules/settings/SearchIndex.js" as SearchIndex

// mujō (無常) — Desktop Settings.
// 5-Category Information Architecture: System, Appearance, Workspace, Hardware, Security & AI.
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
        Component { id: hardwareComp;     HardwarePage {} }
        Component { id: securityComp;     SecurityPage {} }

        SettingsLayout {
            anchors.fill: parent

            // ── 5-Category Unified Information Architecture ───────────────────
            categories: [
                {
                    key: "system", label: "System", icon: "tune", brand: "system",
                    subtitle: "Host, rebuilds, health sentinel, storage cleaner, preferences & apps",
                    page: systemComp, badge: 4,
                    keys: ["system", "overview", "health", "general", "applications", "host", "rebuild", "gc", "sentinel", "preferences", "apps"]
                },
                {
                    key: "appearance", label: "Appearance", icon: "palette", brand: "appearance",
                    subtitle: "Theme presets, accent colors, wallpaper catalog, live engines & motion dynamics",
                    page: appearanceComp, badge: 4,
                    keys: ["appearance", "theme", "colors", "accent", "transparency", "motion", "animations", "wallpapers", "wallpaper", "wallhaven", "wallpaperengine", "effects", "parallax"]
                },
                {
                    key: "workspace", label: "Workspace", icon: "dock_to_bottom", brand: "desktop",
                    subtitle: "Desktop bar layout, dynamic island notch, overlay widgets & staging shelf",
                    page: workspaceComp, badge: 4,
                    keys: ["workspace", "bar", "island", "widgets", "desktop", "shelf"]
                },
                {
                    key: "hardware", label: "Hardware", icon: "monitor", brand: "display",
                    subtitle: "Displays, input devices, keyboard shortcuts, network VPN, power & virtual machines",
                    page: hardwareComp, badge: 5,
                    keys: ["hardware", "display", "displays", "devices", "input", "keyboard", "mouse", "touchpad", "shortcuts", "vm", "machines", "idle", "power", "screen", "network", "vpn", "mullvad", "weather"]
                },
                {
                    key: "security", label: "Security & AI", icon: "shield", brand: "security",
                    subtitle: "Verified boot, AI assistants, progressive trust sandbox, credentials, privacy & alerts",
                    page: securityComp, badge: 5,
                    keys: ["security", "vault", "keyring", "trust", "persistence", "privacy", "tpm", "boot", "ai", "intelligence", "notifications", "dnd", "credentials", "integrity"]
                }
            ]

            searchIndex: SearchIndex.entries
        }
    }
}
