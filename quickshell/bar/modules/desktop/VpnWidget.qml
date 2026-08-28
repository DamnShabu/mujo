import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Mullvad VPN status + one-tap connect. Same runtime-CLI approach the network
// settings page uses (NetworkPanel.qml): `mullvad` is a system package, the
// declarative bits stay in the NixOS mullvad module.
BaseWidget {
    id: root

    property var wcfg: ({})
    readonly property string vpnStyle: wcfg.style !== undefined ? wcfg.style : SettingsBus.get("desktop.vpn.style", "standard")
    readonly property bool showLocation: wcfg.showLocation !== undefined ? !!wcfg.showLocation : SettingsBus.get("desktop.vpn.showLocation", true)
    readonly property string cardStyle: wcfg.cardStyle !== undefined ? wcfg.cardStyle : "glass"

    chromeless: cardStyle === "chromeless"
    property string statusLine: ""
    readonly property bool connected: statusLine.indexOf("Connected") === 0
    readonly property bool connecting: statusLine.indexOf("Connecting") === 0

    // "Connected to se-mma-wg-001 in Malmo, Sweden" -> "Malmo, Sweden"
    readonly property string location: {
        var i = statusLine.indexOf(" in ")
        return i >= 0 ? statusLine.slice(i + 4) : ""
    }

    title: ""
    iconName: ""
    onRetryClicked: { root.error = ""; statusProc.running = true }

    Process {
        id: statusProc
        command: ["mullvad", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.statusLine = this.text.split("\n")[0].trim()
                root.error = ""
            }
        }
        onExited: (code) => { if (code !== 0) root.error = "mullvad unavailable" }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: statusProc.running = true
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            iconName: root.connected ? "vpn_lock" : "vpn_key_off"
            pixelSize: Math.max(24, Math.min(44, Math.floor(root.height * 0.42)))
            color: root.connected ? Theme.success : (root.connecting ? Theme.warning : Theme.textDim)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.connected ? "Connected" : (root.connecting ? "Connecting" : "Disconnected")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(13, Math.min(18, Math.floor(root.height * 0.18)))
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.location !== ""
                text: root.location
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: toggleLabel.implicitWidth + 20
            implicitHeight: 28
            radius: Theme.radiusSm
            color: toggleHh.hovered ? Theme.surfaceHover : Theme.surfaceActive
            border.color: root.connected ? Theme.withAlpha(Theme.error, 0.5) : Theme.withAlpha(Theme.accent, 0.5)

            Text {
                id: toggleLabel
                anchors.centerIn: parent
                text: root.connected ? "Disconnect" : "Connect"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
            HoverHandler { id: toggleHh; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    Quickshell.execDetached(["mullvad", root.connected ? "disconnect" : "connect"])
                    reprobe.restart()
                }
            }
        }
    }

    // mullvad takes a moment to settle; re-read rather than wait for the poll.
    Timer { id: reprobe; interval: 1200; onTriggered: statusProc.running = true }
}
