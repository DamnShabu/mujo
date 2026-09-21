import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// System — the host itself: rebuilding it, watching it, and the preferences
// that are not about how it looks.
SettingsPage {
    id: root

    brand: "system"
    title: "System"
    subtitle: "Host configuration, rebuilds, health sentinel, storage cleaner, preferences and apps."
    isNixos: true
    tab: "rebuild"

    sections: [
        { id: "rebuild", label: "Host & Rebuild", component: rebuildSection,
          description: "Rebuild this machine from the flake, then review or roll back generations." },
        { id: "health", label: "Health & Storage", component: healthSection,
          description: "Watch what the system is doing, and reclaim the disk old builds are holding." },
        { id: "preferences", label: "Preferences", component: prefSection,
          description: "Hostname, timezone, default applications and clipboard history." },
        { id: "apps", label: "Applications", component: appsSection,
          description: "Desktop entries, Flatpaks and launcher integrations." }
    ]

    cardMap: ({
        "NixOS Generation & Store": "rebuild",
        "System Generation History": "rebuild",
        "Local Module Overrides": "rebuild",
        "System Health Sentinel": "health",
        "Sentinel Automation": "health",
        "Process Sentinel & Anomaly Tracker": "health",
        "Storage Reclamation & Cleaner": "health",
        "Default Applications": "preferences",
        "System Parameters & Host Config": "preferences",
        "Clipboard History (cliphist)": "preferences",
        "Applications & Integrations": "apps"
    })

    Component { id: rebuildSection; ColumnLayout { spacing: 14; NixosHostGroup { Layout.fillWidth: true } } }
    Component { id: healthSection; ColumnLayout { spacing: 14; HealthGroup { Layout.fillWidth: true } } }
    Component { id: prefSection; ColumnLayout { spacing: 14; PreferencesGroup { Layout.fillWidth: true } } }
    Component { id: appsSection; ColumnLayout { spacing: 14; ApplicationsGroup { Layout.fillWidth: true } } }
}
