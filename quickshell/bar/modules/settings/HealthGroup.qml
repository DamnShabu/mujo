import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// System Health Sentinel, Process Anomaly Reaping, and Storage Optimizer Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property var cleanData: ({})
    property bool runningOp: false
    property string opLabel: ""
    property var logLines: []
    property bool failedOp: false

    function refreshClean() { cleanScanProc.running = true }
    function refreshAll() {
        SentinelService.refresh()
        root.refreshClean()
    }
    Component.onCompleted: root.refreshAll()

    Process {
        id: cleanScanProc
        command: ["mujo", "clean", "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.cleanData = JSON.parse(this.text) }
                catch (e) { root.cleanData = ({}) }
            }
        }
    }

    Process {
        id: opProc
        stdout: SplitParser { splitMarker: "\n"; onRead: line => root._appendLog(line) }
        stderr: SplitParser { splitMarker: "\n"; onRead: line => root._appendLog(line) }
        onExited: (code, st) => {
            root.runningOp = false
            root.failedOp = code !== 0
            root._appendLog(code === 0 ? "✓ Operation completed successfully" : "✗ Operation exited with code " + code)
            root.refreshAll()
        }
    }

    function _appendLog(l) {
        var a = root.logLines.slice()
        a.push(l)
        if (a.length > 500) a = a.slice(a.length - 500)
        root.logLines = a
    }

    function runClean(target, label) {
        if (root.runningOp) return
        root.logLines = []
        root.failedOp = false
        root.runningOp = true
        root.opLabel = label
        opProc.command = ["mujo", "clean", "apply", target]
        opProc.running = true
    }

    // ── 1. Health Score & Vitals Card ─────────────────────────────────────────
    MujoCard {
        title: "System Health Sentinel"
        iconName: "health_and_safety"
        badgeText: SentinelService.healthStatus.toUpperCase()
        badgeColor: SentinelService.healthScore >= 85 ? Theme.success
                  : (SentinelService.healthScore >= 60 ? Theme.warning : Theme.error)

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                implicitWidth: 60; implicitHeight: 60; radius: 30
                color: Theme.withAlpha(
                    SentinelService.healthScore >= 85 ? Theme.success
                    : (SentinelService.healthScore >= 60 ? Theme.warning : Theme.error), 0.16)
                border.color: SentinelService.healthScore >= 85 ? Theme.success
                            : (SentinelService.healthScore >= 60 ? Theme.warning : Theme.error)
                border.width: 2

                ColumnLayout {
                    anchors.centerIn: parent; spacing: 0
                    Text {
                        text: String(SentinelService.healthScore)
                        color: SentinelService.healthScore >= 85 ? Theme.success
                             : (SentinelService.healthScore >= 60 ? Theme.warning : Theme.error)
                        font.family: Theme.fontMono
                        font.pixelSize: 20
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: "SCORE"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel - 1
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text {
                    text: SentinelService.healthScore >= 90 ? "System Performance is Optimal"
                        : (SentinelService.healthScore >= 70 ? "Minor Performance Bottlenecks Detected"
                        : "Attention Needed: Resource Runaways Detected")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                }
                Text {
                    text: "Anomalies: " + (SentinelService.anomalies ? SentinelService.anomalies.length : 0) +
                          " · Zombies: " + SentinelService.zombieCount +
                          (root.cleanData && root.cleanData.totalReclaimableMb ? (" · Reclaimable: " + (root.cleanData.totalReclaimableMb / 1024).toFixed(1) + " GB") : "")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            DialogButton {
                text: "Scan"
                enabled: !root.runningOp
                onClicked: root.refreshAll()
            }
            DialogButton {
                text: "Optimize All"
                primary: true
                enabled: !root.runningOp
                onClicked: root.runClean("all", "Full System Optimization")
            }
        }
    }

    // ── 2. Maintenance Log Output ─────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 140
        visible: root.runningOp || root.logLines.length > 0
        radius: Theme.radiusMd
        color: Theme.bg
        border.color: root.failedOp ? Theme.error : (root.runningOp ? Theme.accent : Theme.border)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Spinner { size: 13; visible: root.runningOp }
                MaterialIcon {
                    visible: !root.runningOp
                    iconName: root.failedOp ? "error" : "check_circle"
                    pixelSize: 14
                    color: root.failedOp ? Theme.error : Theme.success
                }
                Text {
                    text: root.opLabel || "Maintenance Operation"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                DialogButton { text: "Cancel"; visible: root.runningOp; onClicked: if (root.runningOp) opProc.running = false }
                DialogButton { text: "Clear"; visible: !root.runningOp && root.logLines.length > 0; onClicked: root.logLines = [] }
            }

            ListView {
                id: logView
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                model: root.logLines
                boundsBehavior: Flickable.DragAndOvershootBounds
                onCountChanged: positionViewAtEnd()
                delegate: Text {
                    required property var modelData
                    width: logView.width
                    text: modelData
                    color: Theme.textSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }
            }
        }
    }

    // ── 3. Storage Reclamation Cards ──────────────────────────────────────────
    MujoCard {
        title: "Storage Reclamation & Cleaner"
        iconName: "cleaning_services"

        Flow {
            Layout.fillWidth: true
            spacing: 10

            // 1. Nix Store
            Rectangle {
                width: (parent.width - 10) / 2
                implicitHeight: 100
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        MaterialIcon { iconName: "delete_sweep"; pixelSize: 16; color: Theme.accent }
                        Text { text: "NixOS Generations"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; font.bold: true; Layout.fillWidth: true }
                    }
                    Text {
                        text: root.cleanData && root.cleanData.nix ? (root.cleanData.nix.label + " (~" + ((root.cleanData.nix.reclaimableMb || 0) / 1024).toFixed(1) + " GB)") : "Scanning generations…"
                        color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel
                    }
                    DialogButton {
                        text: "Clean Generations"
                        enabled: !root.runningOp
                        onClicked: root.runClean("nix", "Cleaning old generations & optimizing Nix store")
                    }
                }
            }

            // 2. Journal Logs
            Rectangle {
                width: (parent.width - 10) / 2
                implicitHeight: 100
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        MaterialIcon { iconName: "description"; pixelSize: 16; color: Theme.accent }
                        Text { text: "Systemd Journals"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; font.bold: true; Layout.fillWidth: true }
                    }
                    Text {
                        text: root.cleanData && root.cleanData.journal ? (root.cleanData.journal.label + " (~" + (root.cleanData.journal.reclaimableMb || 0) + " MB)") : "Scanning journal size…"
                        color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel
                    }
                    DialogButton {
                        text: "Vacuum Logs (<=100MB)"
                        enabled: !root.runningOp
                        onClicked: root.runClean("journal", "Vacuuming systemd journal logs to <=100MB")
                    }
                }
            }

            // 3. User & App Caches
            Rectangle {
                width: (parent.width - 10) / 2
                implicitHeight: 100
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        MaterialIcon { iconName: "folder_delete"; pixelSize: 16; color: Theme.accent }
                        Text { text: "Disposable Caches"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; font.bold: true; Layout.fillWidth: true }
                    }
                    Text {
                        text: root.cleanData && root.cleanData.caches ? ("Thumbnails, shaders, trash (~" + (root.cleanData.caches.totalMb || 0) + " MB)") : "Scanning caches…"
                        color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel
                    }
                    DialogButton {
                        text: "Purge Caches"
                        enabled: !root.runningOp
                        onClicked: root.runClean("caches", "Purging thumbnail, shader, and trash caches")
                    }
                }
            }

            // 4. Memory & ZRAM
            Rectangle {
                width: (parent.width - 10) / 2
                implicitHeight: 100
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        MaterialIcon { iconName: "memory"; pixelSize: 16; color: Theme.accent }
                        Text { text: "ZRAM & Memory Compaction"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; font.bold: true; Layout.fillWidth: true }
                    }
                    Text {
                        text: "Compact ZRAM swap buffers and drop inactive kernel page cache."
                        color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel
                    }
                    DialogButton {
                        text: "Compact Memory"
                        enabled: !root.runningOp
                        onClicked: root.runClean("memory", "Compacting ZRAM swap and dropping inactive caches")
                    }
                }
            }
        }
    }

    // ── 4. Sentinel Automation Card ───────────────────────────────────────────
    // SentinelService reads these three keys on every scan; the migration to
    // HealthGroup dropped their toggles, leaving the automation reachable only
    // through `mujo settings set`. Restored declaratively.
    MujoCard {
        title: "Sentinel Automation"
        iconName: "auto_mode"

        SettingRow {
            path: "sentinel.enable"
            def: true
            kind: "toggle"
            iconName: "monitor_heart"
            title: "Process Sentinel"
            description: "Monitor background tasks for runaway CPU, memory leaks, and unresponsive states."
        }

        SettingRow {
            path: "sentinel.autoReapZombies"
            def: true
            kind: "toggle"
            iconName: "pest_control"
            title: "Silent Zombie Reaping"
            description: "Clean up defunct child processes in the background without prompting."
            disabled: !SettingsBus.get("sentinel.enable", true)
        }

        SettingRow {
            path: "sentinel.autoKillRunaways"
            def: true
            kind: "toggle"
            iconName: "block"
            title: "3-Minute Auto-Kill Protection"
            description: "Terminate un-whitelisted processes that sustain three consecutive runaway flags without progress."
            disabled: !SettingsBus.get("sentinel.enable", true)
        }
    }

    // ── 5. Problematic Processes Card ─────────────────────────────────────────
    MujoCard {
        title: "Process Sentinel & Anomaly Tracker"
        iconName: "pest_control"
        badgeText: SentinelService.problematicProcesses.length > 0 ? (SentinelService.problematicProcesses.length + " ANOMALIES") : "ALL CLEAN"
        badgeColor: SentinelService.problematicProcesses.length > 0 ? Theme.error : Theme.success

        actions: RowLayout {
            spacing: 6
            DialogButton {
                text: "Reap Zombies (" + SentinelService.zombieCount + ")"
                visible: SentinelService.zombieCount > 0
                onClicked: SentinelService.reap()
            }
            IconButton {
                iconName: "refresh"
                onClicked: SentinelService.refresh()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                visible: SentinelService.problematicProcesses.length === 0
                text: "All background processes and threads are operating normally within CPU and memory budget."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Repeater {
                model: SentinelService.problematicProcesses
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Theme.radiusSm
                    color: Theme.bg
                    border.color: modelData.warning || modelData.type === "cpu_runaway" ? Theme.error : Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10

                        MaterialIcon {
                            iconName: modelData.type === "zombie" ? "pest_control"
                                    : (modelData.type === "cpu_runaway" ? "speed"
                                    : (modelData.type === "mem_hog" ? "memory" : "warning"))
                            pixelSize: 18
                            color: Theme.error
                        }

                        Text {
                            text: String(modelData.pid)
                            color: Theme.textDim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            Layout.preferredWidth: 50
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: modelData.name || "Unknown"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            Text { text: modelData.reason || ""; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel }
                        }

                        DialogButton {
                            text: "Kill"
                            onClicked: SentinelService.killProcess(modelData.pid)
                        }
                    }
                }
            }
        }
    }
}
