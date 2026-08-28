import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// SysmonWidget: Standardized desktop system monitor widget component.
// Utilizes BaseWidget for uniform glassmorphic styling, async process management, and interaction.
BaseWidget {
    id: root

    property var wcfg: ({})
    readonly property string sysStyle: wcfg.style !== undefined ? wcfg.style : SettingsBus.get("desktop.sysmon.style", "bars")
    readonly property bool showCpu: wcfg.showCpu !== undefined ? !!wcfg.showCpu : SettingsBus.get("desktop.sysmon.showCpu", true)
    readonly property bool showMem: wcfg.showMem !== undefined ? !!wcfg.showMem : SettingsBus.get("desktop.sysmon.showMem", true)
    readonly property int refreshSec: Math.max(1, wcfg.refreshSec !== undefined ? Number(wcfg.refreshSec) : SettingsBus.get("desktop.sysmon.refreshSec", 3))
    readonly property string cardStyle: wcfg.cardStyle !== undefined ? wcfg.cardStyle : "glass"

    chromeless: cardStyle === "chromeless"
    title: ""
    iconName: ""

    property int cpu: 0
    property int mem: 0
    property string memText: ""

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
        interval: root.refreshSec * 1000
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
        anchors.margins: root.chromeless ? 0 : 8
        spacing: root.sysStyle === "compact" ? 4 : 8

        Item { Layout.fillHeight: true }

        // Standard Bar mode
        SysBar {
            visible: root.showCpu && root.sysStyle !== "pills"
            Layout.alignment: Qt.AlignHCenter
            width: Math.min(220, Math.max(80, root.width - 24))
            label: "CPU"
            value: root.cpu
            caption: root.cpu + "%"
        }

        SysBar {
            visible: root.showMem && root.sysStyle !== "pills"
            Layout.alignment: Qt.AlignHCenter
            width: Math.min(220, Math.max(80, root.width - 24))
            label: "RAM"
            value: root.mem
            caption: root.memText
        }

        // Pill / Gauge mode
        RowLayout {
            visible: root.sysStyle === "pills"
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            Rectangle {
                visible: root.showCpu
                implicitWidth: cpuPillCol.implicitWidth + 20
                implicitHeight: 48
                radius: Theme.radiusMd
                color: Theme.surfaceActive
                border.color: root.cpu > 80 ? Theme.error : Theme.border

                ColumnLayout {
                    id: cpuPillCol
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        text: "CPU"
                        color: Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: root.cpu + "%"
                        color: root.cpu > 80 ? Theme.error : Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Rectangle {
                visible: root.showMem
                implicitWidth: memPillCol.implicitWidth + 20
                implicitHeight: 48
                radius: Theme.radiusMd
                color: Theme.surfaceActive
                border.color: root.mem > 85 ? Theme.error : Theme.border

                ColumnLayout {
                    id: memPillCol
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        text: "RAM"
                        color: Theme.textSecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: root.mem + "%"
                        color: root.mem > 85 ? Theme.error : Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
