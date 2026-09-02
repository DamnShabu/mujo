import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// The launcher's workflow preferences: favourites, recents and the behaviour
// toggles behind them. Reads and writes SettingsBus directly, so it needs
// nothing from the panel around it.
ColumnLayout {
    id: section

    spacing: 14

    readonly property var favorites: SettingsBus.get("apps.favorites", [])
    readonly property var recents: SettingsBus.get("apps.recent", [])

    function nameFor(id) {
        var a = (DesktopEntries.applications ? DesktopEntries.applications.values : []) || []
        for (var i = 0; i < a.length; i++) if (a[i] && a[i].id === id) return a[i].name
        return id
    }

    MujoCard {
        title: "Launcher Actions"
        iconName: "bolt"

        MujoSettingRow {
            iconName: "power_settings_new"
            title: "Power Actions in Command Palette"
            description: "Show Log out, Reboot, Shut down, and Suspend in the “/” command palette."

            ToggleSwitch {
                checked: SettingsBus.get("launcher.enableDangerousActions", false)
                onToggled: function (c) { SettingsBus.set("launcher.enableDangerousActions", c) }
            }
        }
    }

    // Favourites Card
    MujoCard {
        title: "Favourite Apps (Pinned to Launcher)"
        iconName: "star"
        badgeText: section.favorites.length + " PINNED"

        Flow {
            Layout.fillWidth: true
            spacing: 8
            visible: section.favorites.length > 0

            Repeater {
                model: section.favorites
                delegate: Rectangle {
                    id: favChip
                    required property var modelData
                    implicitWidth: fl.implicitWidth + 20; implicitHeight: 30
                    radius: Theme.radiusMd
                    color: Theme.surface
                    border.color: Theme.borderStrong
                    RowLayout {
                        id: fl; anchors.centerIn: parent; spacing: 6
                        MaterialIcon { iconName: "star"; pixelSize: 14; color: Theme.warning }
                        Text {
                            text: section.nameFor(favChip.modelData)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        MaterialIcon {
                            iconName: "close"
                            pixelSize: 14
                            color: fh.hovered ? Theme.text : Theme.textDim
                            HoverHandler { id: fh; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: SettingsBus.set("apps.favorites", section.favorites.filter(function (x) { return x !== favChip.modelData }))
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: section.favorites.length === 0
            text: "Star apps in the launcher's grid view to pin them here."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // Recents Card
    MujoCard {
        title: "Recent Apps History"
        iconName: "history"
        badgeText: section.recents.length + " RECENT"

        actions: [
            DialogButton {
                visible: section.recents.length > 0
                text: "Clear History"
                onClicked: SettingsBus.set("apps.recent", [])
            }
        ]

        Flow {
            Layout.fillWidth: true
            spacing: 8
            visible: section.recents.length > 0

            Repeater {
                model: section.recents
                delegate: Rectangle {
                    id: recChip
                    required property var modelData
                    implicitWidth: rl.implicitWidth + 18; implicitHeight: 28
                    radius: Theme.radiusMd
                    color: Theme.surface
                    border.color: Theme.border
                    Text {
                        id: rl; anchors.centerIn: parent
                        text: section.nameFor(recChip.modelData)
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
        }

        Text {
            visible: section.recents.length === 0
            text: "No recently launched apps yet."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
