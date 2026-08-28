import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// LauncherActionBar: Modernized bottom action & shortcut bar for Mujo (無常).
// Provides contextual app controls, keyboard shortcut hints, and a glassmorphic
// dropdown actions menu.
Rectangle {
    id: root

    property var selectedEntry: null
    property string screenName: ""
    property bool dropdownOpen: false
    property point dropdownPos: Qt.point(0, 0)
    property var dropdownParent: null
    signal triggered
    signal requestClose

    Layout.fillWidth: true
    Layout.preferredHeight: 38
    radius: Theme.radiusMd
    color: Theme.surface
    border.color: Theme.border
    border.width: 1
    visible: root.selectedEntry != null

    function entryIcon(entry) {
        if (!entry) return "open_in_new"
        var n = entry.name ? entry.name.toLowerCase() : ""
        if (n.includes("browser") || n.includes("firefox") || n.includes("chrome") || n.includes("zen"))
            return "language"
        if (n.includes("terminal") || n.includes("kitty") || n.includes("alacritty"))
            return "terminal"
        if (n.includes("file") || n.includes("nautilus") || n.includes("dolphin"))
            return "folder"
        if (n.includes("music") || n.includes("spotify"))
            return "music_note"
        if (n.includes("video") || n.includes("mpv"))
            return "play_circle"
        if (n.includes("image") || n.includes("gimp") || n.includes("inkscape"))
            return "image"
        if (n.includes("code") || n.includes("vscode") || n.includes("cursor") || n.includes("zed"))
            return "code"
        if (n.includes("setting"))
            return "settings"
        if (n.includes("chat") || n.includes("discord") || n.includes("signal") || n.includes("telegram"))
            return "chat"
        if (n.includes("mail"))
            return "mail"
        return "open_in_new"
    }

    function copyToClipboard(text) {
        copyProc.command = ["wl-copy", text]
        copyProc.running = true
    }

    // Anchor the menu above the Actions button. Both the button and Ctrl+K go
    // through here — computing the position in only one of them left the other
    // opening the menu at the panel's top-left corner.
    function toggleDropdown() {
        if (!root.dropdownOpen) {
            var btnPos = actionsBtn.mapToItem(root.dropdownParent, 0, 0)
            root.dropdownPos = Qt.point(
                Math.max(0, btnPos.x + actionsBtn.width - 240),
                Math.max(0, btnPos.y - 176)
            )
        }
        root.dropdownOpen = !root.dropdownOpen
    }

    // Indices are positions in LauncherBody's dropdown.model — keep the two in
    // step. 1 (favorite) and 2 (add to group) need launcher state, so the owner
    // handles those before delegating here.
    function triggerAction(index) {
        if (!root.selectedEntry) return
        var e = root.selectedEntry

        if (index === 0) {
            Launch.app(e, root.screenName)
        } else if (index === 3) {
            copyToClipboard(e.name || "")
        } else if (index === 4) {
            // DesktopEntry exposes no path to the .desktop file, so the id is
            // what is actually copyable — and it is the key apps.favorites and
            // apps.groups are stored under.
            copyToClipboard(e.id || "")
        } else if (index === 5) {
            copyToClipboard(e.execString || "")
        } else {
            return
        }
        root.triggered()
    }

    Process { id: copyProc; command: ["wl-copy"] }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        // Primary Action Button
        RowLayout {
            spacing: 6
            MaterialIcon {
                iconName: root.entryIcon(root.selectedEntry)
                pixelSize: 14
                color: Theme.accent
            }
            Text {
                text: "Launch " + (root.selectedEntry ? root.selectedEntry.name : "Application")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: 260
            }
            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 18
                radius: Theme.radiusSm
                color: Theme.surfaceActive
                border.color: Theme.borderStrong

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "keyboard_return"
                    pixelSize: 12
                    color: Theme.accent
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Contextual hints
        RowLayout {
            spacing: 8
            visible: parent.width > 460

            RowLayout {
                spacing: 4
                Rectangle {
                    implicitWidth: tabKey.implicitWidth + 8
                    implicitHeight: 18
                    radius: 3
                    color: Theme.surfaceActive
                    border.color: Theme.borderStrong
                    Text {
                        id: tabKey
                        anchors.centerIn: parent
                        text: "Tab"
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel - 1
                    }
                }
                Text {
                    text: "Grid"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // Actions (Ctrl+K) Button
        MouseArea {
            id: actionsBtn
            Layout.preferredWidth: actionsBtnRow.implicitWidth + 14
            Layout.preferredHeight: 26
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSm
                color: actionsBtn.containsMouse || root.dropdownOpen ? Theme.surfaceHover : "transparent"
                border.color: root.dropdownOpen ? Theme.accent : (actionsBtn.containsMouse ? Theme.borderStrong : "transparent")
                border.width: 1
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            }

            RowLayout {
                id: actionsBtnRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    iconName: "more_horiz"
                    pixelSize: 14
                    color: root.dropdownOpen ? Theme.accent : Theme.textSecondary
                }

                Text {
                    text: "Actions"
                    color: root.dropdownOpen ? Theme.text : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: root.dropdownOpen
                }

                Rectangle {
                    Layout.preferredWidth: kLabel.implicitWidth + 8
                    Layout.preferredHeight: 18
                    radius: 3
                    color: Theme.surfaceActive
                    border.color: root.dropdownOpen ? Theme.accent : Theme.borderStrong

                    Text {
                        id: kLabel
                        anchors.centerIn: parent
                        text: "Ctrl K"
                        color: root.dropdownOpen ? Theme.accent : Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel - 1
                        font.bold: true
                    }
                }
            }

            onClicked: root.toggleDropdown()
        }
    }
}
