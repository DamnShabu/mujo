import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Desktop Companion Integrations, Flatpak Packages & Permissions, and Launcher Pins Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property string activeTab: "integrations"
    readonly property var tabs: [
        { id: "integrations", label: "Integrations & Services", icon: "extension" },
        { id: "flatpaks",     label: "Flatpak Applications",    icon: "inventory_2" },
        { id: "launcher",     label: "Launcher & Workflow",     icon: "stars" }
    ]

    MujoCard {
        title: "Applications & Integrations"
        iconName: "apps"

        actions: RowLayout {
            spacing: 6
            MujoSegmented {
                model: root.tabs
                current: root.activeTab
                onSelected: function(id) { root.activeTab = id }
            }
            IconButton {
                iconName: "refresh"
                onClicked: {
                    integrationsTab.refreshDetection()
                    flatpaksTab.refresh()
                }
            }
        }

        ApplicationsIntegrationsTab {
            id: integrationsTab
            visible: root.activeTab === "integrations"
            Layout.fillWidth: true
        }

        ApplicationsFlatpaksTab {
            id: flatpaksTab
            visible: root.activeTab === "flatpaks"
            Layout.fillWidth: true
        }

        ApplicationsLauncherTab {
            id: launcherTab
            visible: root.activeTab === "launcher"
            Layout.fillWidth: true
        }
    }
}
