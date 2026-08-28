import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"

// SysmonWidget: Standardized desktop system monitor widget component.
// Utilizes BaseWidget for uniform glassmorphic styling, async process management, and interaction.
BaseWidget {
    id: root

    property var wcfg: ({})
    property int cpu: 0
    property int mem: 0
    property string memText: ""

    title: ""
    iconName: ""

    Process {
        id: smProc
        command: ["mujo", "sysmon"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    root.cpu = d.cpu || 0
                    root.mem = d.mem || 0
                    root.memText = (d.memUsedGb !== undefined ? d.memUsedGb : "0") + " / " + (d.memTotalGb !== undefined ? d.memTotalGb : "0") + " GB"
                    root.loading = false
                    root.error = ""
                } catch (e) {
                    if (!root.loading) root.error = "sysmon unavailable"
                }
            }
        }
        onExited: (code) => {
            if (code !== 0 && root.error === "") {
                root.error = "sysmon exited (" + code + ")"
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: smProc.running = true
        Component.onCompleted: {
            root.loading = true
            smProc.running = true
        }
    }

    onRetryClicked: {
        root.error = ""
        root.loading = true
        smProc.running = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Item { Layout.fillHeight: true }

        SysBar {
            Layout.alignment: Qt.AlignHCenter
            width: Math.min(220, Math.max(80, root.width - 24))
            label: "CPU"
            value: root.cpu
            caption: root.cpu + "%"
        }

        SysBar {
            Layout.alignment: Qt.AlignHCenter
            width: Math.min(220, Math.max(80, root.width - 24))
            label: "RAM"
            value: root.mem
            caption: root.memText
        }

        Item { Layout.fillHeight: true }
    }
}
