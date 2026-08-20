import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell


Rectangle {
    id: root

    property var selectedEntry: null
    property bool dropdownOpen: false
    property point dropdownPos: Qt.point(0, 0)
    property var dropdownParent: null
    signal triggered
    signal requestClose

    Layout.fillWidth: true
    Layout.preferredHeight: 32
    radius: 5
    color: Theme.surface
    border.color: Theme.border
    border.width: 1
    visible: root.selectedEntry != null

    function entryIcon(entry) {
        if (!entry) return ""
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
        if (n.includes("code") || n.includes("vscode") || n.includes("cursor"))
            return "code"
        if (n.includes("setting"))
            return "settings"
        if (n.includes("store") || n.includes("discover"))
            return "store"
        if (n.includes("chat") || n.includes("discord") || n.includes("signal"))
            return "chat"
        if (n.includes("mail"))
            return "mail"
        return "open_in_new"
    }

    function copyToClipboard(text) {
        copyProc.command = ["wl-copy", text]
        copyProc.running = true
    }

    function triggerAction(index) {
        if (!root.selectedEntry) return
        var e = root.selectedEntry

        if (index === 0) {
            e.execute()
            root.triggered()
        } else if (index === 1) {
            copyToClipboard(e.name || "")
            root.triggered()
        } else if (index === 2) {
            copyToClipboard(e.fileName || "")
            root.triggered()
        } else if (index === 3) {
            var execPath = e.executable || ""
            if (execPath.indexOf("/") === 0) {
                openDirProc.command = ["xdg-open", execPath.substring(0, execPath.lastIndexOf("/"))]
                openDirProc.running = true
            }
            root.triggered()
        } else if (index === 4) {
            copyToClipboard(e.executable || "")
            root.triggered()
        }
    }

    Process {
        id: copyProc
        command: ["wl-copy"]
    }

    Process {
        id: openDirProc
        command: ["xdg-open"]
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        MaterialIcon {
            iconName: root.entryIcon(root.selectedEntry)
            pixelSize: 14
            color: Theme.textSecondary
        }

        Text {
            text: "Open Application"
            color: Theme.text
            font.pixelSize: 12
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            radius: 3
            color: Theme.border

            MaterialIcon {
                anchors.centerIn: parent
                iconName: "keyboard_return"
                pixelSize: 12
                color: Theme.textSecondary
            }
        }

        Item { Layout.preferredWidth: 6 }

        MouseArea {
            id: actionsBtn
            Layout.preferredWidth: actionsBtnRow.implicitWidth + 12
            Layout.preferredHeight: 24
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: actionsBtn.containsMouse ? Theme.border : "transparent"
            }

            RowLayout {
                id: actionsBtnRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "Actions"
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }

                Rectangle {
                    Layout.preferredWidth: kLabel.implicitWidth + 8
                    Layout.preferredHeight: 16
                    radius: 3
                    color: Theme.border

                    Text {
                        id: kLabel
                        anchors.centerIn: parent
                        text: "Ctrl K"
                        color: Theme.textSecondary
                        font.pixelSize: 9
                    }
                }
            }

            onClicked: {
                var btnPos = actionsBtn.mapToItem(root.dropdownParent, 0, 0)
                root.dropdownPos = Qt.point(
                    Math.max(0, btnPos.x + actionsBtn.width - 240),
                    Math.max(0, btnPos.y - 170)
                )
                root.dropdownOpen = !root.dropdownOpen
            }
        }
    }
}
