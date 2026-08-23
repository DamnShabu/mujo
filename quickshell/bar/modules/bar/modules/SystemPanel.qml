import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// System / NixOS — configuration status and actions. The Settings app is a
// control layer over the existing flake; this page surfaces it and offers a
// safe, visible rebuild (runs in a terminal so the polkit prompt + output show).
Item {
    id: root

    property var info: []

    Process {
        id: infoProc
        command: ["sh", "-c",
            "printf 'Host\\t%s\\n' \"$(hostname)\"; "
          + "printf 'NixOS\\t%s\\n' \"$(nixos-version 2>/dev/null)\"; "
          + "printf 'Kernel\\t%s\\n' \"$(uname -r)\"; "
          + "printf 'Uptime\\t%s\\n' \"$(uptime -p 2>/dev/null | sed 's/^up //')\"; "
          + "printf 'Generation\\t%s\\n' \"$(basename $(readlink -f /run/current-system))\"; "
          + "printf 'Flake\\t%s\\n' \"${NIXCONF:-$HOME/nixconf}\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = this.text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("\t")
                    if (p.length >= 2) out.push({ k: p[0], v: p[1] })
                }
                root.info = out
            }
        }
    }
    Component.onCompleted: infoProc.running = true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 20

        RowLayout {
            spacing: 14
            BrandIcon { brand: "nixos"; size: 48 }
            ColumnLayout {
                spacing: 2
                Text { text: "System / NixOS"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTitle + 7; font.bold: true }
                Text { text: "Configuration status and rebuild."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: Theme.border
            implicitHeight: infoCol.implicitHeight + 24
            ColumnLayout {
                id: infoCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 0
                Repeater {
                    model: root.info
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        spacing: 12
                        Text { Layout.preferredWidth: 120; text: modelData.k; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                        Text { Layout.fillWidth: true; text: modelData.v; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideMiddle }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            SectionLabel { text: "Actions" }
            RowLayout {
                spacing: 10
                DialogButton { text: "Rebuild & switch"; primary: true; onClicked: Quickshell.execDetached(["mujo", "rebuild"]) }
                DialogButton { text: "Reload niri config"; onClicked: Quickshell.execDetached(["niri", "msg", "action", "reload-config"]) }
            }
            Text {
                Layout.fillWidth: true
                text: "Rebuild runs in a background tmux session — authenticate at the polkit "
                    + "prompt, then watch progress with:  tmux attach -t mujo-rebuild"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }

        Item { Layout.fillHeight: true }
    }
}
