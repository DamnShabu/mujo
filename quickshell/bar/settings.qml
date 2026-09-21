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
            //
            // `subs` are the sub-categories the sidebar expands under a
            // category. Each id is a `tab` value the destination page already
            // understands — selecting one routes through the same
            // `revealCard()` path the omni-search uses, so the sidebar drives
            // the page without a second navigation model. Keep an id in step
            // with its page's `tabIds`, or the row selects the category and
            // lands on whichever tab was last open.
            categories: [
                {
                    key: "system", label: "System", icon: "tune", brand: "system",
                    subtitle: "Host, rebuilds, health sentinel, storage cleaner, preferences & apps",
                    page: systemComp,
                    subs: [
                        { id: "rebuild",     label: "Host & Rebuild",   icon: "autorenew" },
                        { id: "health",      label: "Health & Storage", icon: "health_and_safety" },
                        { id: "preferences", label: "Preferences",      icon: "tune" },
                        { id: "apps",        label: "Applications",     icon: "apps" }
                    ],
                    keys: ["system", "overview", "health", "general", "applications", "host", "rebuild", "gc", "sentinel", "preferences", "apps"]
                },
                {
                    key: "appearance", label: "Appearance", icon: "palette", brand: "appearance",
                    subtitle: "Theme presets, accent colors, and motion dynamics",
                    page: appearanceComp,
                    subs: [
                        { id: "themes", label: "Themes & Colors", icon: "palette" },
                        { id: "motion", label: "Motion Dynamics", icon: "animation" }
                    ],
                    keys: ["appearance", "theme", "colors", "accent", "transparency", "motion", "animations"]
                },
                {
                    key: "workspace", label: "Workspace", icon: "dock_to_bottom", brand: "desktop",
                    subtitle: "Desktop bar layout, dynamic island notch, overlay widgets, notifications, weather & staging shelf",
                    page: workspaceComp,
                    subs: [
                        { id: "bar",           label: "Desktop Bar",          icon: "dock_to_bottom" },
                        { id: "island",        label: "Dynamic Island",       icon: "dynamic_form" },
                        { id: "widgets",       label: "Overlay Widgets",      icon: "widgets" },
                        { id: "notifications", label: "Notifications & DND",  icon: "notifications" },
                        { id: "weather",       label: "Weather",              icon: "wb_sunny" },
                        { id: "shelf",         label: "Shelf",                icon: "inventory_2" }
                    ],
                    keys: ["workspace", "bar", "island", "widgets", "desktop", "shelf", "notifications", "dnd", "weather"]
                },
                {
                    key: "hardware", label: "Hardware", icon: "monitor", brand: "display",
                    subtitle: "Displays, input devices, keyboard shortcuts, power & virtual machines",
                    page: hardwareComp,
                    subs: [
                        { id: "displays", label: "Displays",         icon: "monitor" },
                        { id: "input",    label: "Input & Keys",     icon: "keyboard" },
                        { id: "power",    label: "Power & Sleep",    icon: "power_settings_new" },
                        { id: "network",  label: "Network & VPN",    icon: "vpn_key" },
                        { id: "vm",       label: "Virtual Machines", icon: "dns" }
                    ],
                    keys: ["hardware", "display", "displays", "devices", "input", "keyboard", "mouse", "touchpad", "shortcuts", "vm", "machines", "idle", "power", "screen", "network", "vpn", "mullvad"]
                },
                {
                    key: "security", label: "Security & Privacy", icon: "shield", brand: "security",
                    subtitle: "Verified boot, progressive trust sandbox, credentials, AI assistants & persistence",
                    page: securityComp,
                    subs: [
                        { id: "integrity",   label: "System Integrity",      icon: "verified_user" },
                        { id: "trust",       label: "Trust & Sandbox",       icon: "shield" },
                        { id: "keyring",     label: "Credentials",           icon: "password" },
                        { id: "ai",          label: "AI Assistants",         icon: "psychology" },
                        { id: "persistence", label: "Persistence & Privacy", icon: "security" }
                    ],
                    keys: ["security", "vault", "keyring", "trust", "persistence", "privacy", "tpm", "boot", "ai", "intelligence", "credentials", "integrity"]
                }
            ]

            searchIndex: SearchIndex.entries
        }
    }
}
