import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// Applications & Integrations Control Center — Mujo (無常).
// Manager for integrated desktop services, installed Flatpaks & sandboxing permissions,
// and launcher workflow preferences (favorites & recents).
Item {
    id: root

    // ── Tab navigation state ──────────────────────────────────────────────────
    property string activeTab: "integrations" // integrations | trust | flatpaks | launcher
    readonly property var tabs: [
        { id: "integrations", label: "Integrations & Services", icon: "extension" },
        { id: "trust",        label: "Progressive Trust",       icon: "shield" },
        { id: "flatpaks",     label: "Flatpak Applications",    icon: "inventory_2" },
        { id: "launcher",     label: "Launcher & Workflow",     icon: "stars" }
    ]

    MujoFlickable {
        anchors.fill: parent
        contentHeight: mainCol.implicitHeight + 48

        ColumnLayout {
            id: mainCol
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 16

            // ── Hero Banner ───────────────────────────────────────────────────
            MujoHero {
                brand: "applications"
                title: "Applications & Integrations"
                subtitle: "Manage integrated companion services, Flatpak sandboxes, and launcher pinned favorites."
                badgeText: flatpaksTab.flatpaksList.length > 0
                           ? (flatpaksTab.flatpaksList.length + " FLATPAKS") : "INTEGRATED"
                badgeColor: Theme.accent

                IconButton {
                    iconName: "refresh"
                    onClicked: {
                        integrationsTab.refreshDetection()
                        flatpaksTab.refresh()
                    }
                }
            }

            // ── Segmented Tab Selector ───────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    Repeater {
                        model: root.tabs
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: root.activeTab === modelData.id
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSm
                            color: active ? Theme.surfaceActive : (tab_hh.hovered ? Theme.surfaceHover : "transparent")
                            border.color: active ? Theme.borderStrong : "transparent"
                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                MaterialIcon {
                                    iconName: modelData.icon
                                    pixelSize: 16
                                    color: active ? Theme.accent : Theme.textSecondary
                                }
                                Text {
                                    text: modelData.label
                                    color: active ? Theme.text : Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: active
                                }
                            }
                            HoverHandler { id: tab_hh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.activeTab = modelData.id }
                        }
                    }
                }
            }

            ApplicationsIntegrationsTab {
                id: integrationsTab
                visible: root.activeTab === "integrations"
                Layout.fillWidth: true
            }

            ApplicationsTrustTab {
                id: trustTab
                visible: root.activeTab === "trust"
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

            Item { implicitHeight: 12 }
        }
    }
}
