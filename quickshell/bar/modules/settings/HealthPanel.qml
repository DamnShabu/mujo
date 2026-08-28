import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// System Health, Process Sentinel & PC Care Optimizer (WP-Health).
// Combines live process anomaly detection, zombie reaping, one-click storage
// cleaning (Nix generations, journals, caches), ZRAM memory compaction, and
// AI crash recovery policies.
Item {
    id: root

    function bset(k, v) { SettingsBus.set(k, v) }

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
                try {
                    root.cleanData = JSON.parse(this.text)
                } catch (e) {
                    root.cleanData = ({})
                }
            }
        }
    }

    // ── Streaming Operations ──
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

    function cancelOp() {
        if (root.runningOp) opProc.running = false
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 20

            MujoHero {
                brand: "health"
                title: "System Health & Optimizer"
                subtitle: "Real-time process sentinel, runaway task cleanup, storage reclamation, and AI crash assistance."
                badgeText: SentinelService.healthStatus.toUpperCase()
                badgeColor: SentinelService.healthScore >= 85 ? Theme.success
                          : (SentinelService.healthScore >= 60 ? Theme.warning : Theme.error)
                activeState: root.runningOp || SentinelService.healthScore < 85
            }

            // ── Health Score & Vitals Card ──
            Rectangle {
                Layout.fillWidth: true
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.border
                implicitHeight: scoreCol.implicitHeight + 28

                ColumnLayout {
                    id: scoreCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true; spacing: 16
                        // Score Circle Indicator
                        Rectangle {
                            implicitWidth: 64; implicitHeight: 64; radius: 32
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
                                    font.pixelSize: 22
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: "SCORE"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabel
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Text {
                                text: SentinelService.healthScore >= 90 ? "System Performance is Optimal"
                                    : (SentinelService.healthScore >= 70 ? "Minor Performance Bottlenecks Detected"
                                    : "Attention Needed: Resource Runaway Detected")
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
                            text: "Scan Now"
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
            }

            // ── Live Streaming Log Pane ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
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
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        DialogButton { text: "Cancel"; visible: root.runningOp; onClicked: root.cancelOp() }
                        DialogButton { text: "Clear"; visible: !root.runningOp && root.logLines.length > 0; onClicked: root.logLines = [] }
                    }

                    ListView {
                        id: logView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        model: root.logLines
                        boundsBehavior: Flickable.StopAtBounds
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

            // ── Storage & Maintenance Cleaner Suite ──
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                SectionLabel { text: "System Cleaner & Storage Optimization" }

                Flow {
                    Layout.fillWidth: true
                    spacing: 12

                    // 1. Nix Store Card
                    Rectangle {
                        width: (parent.width - 12) / 2
                        implicitHeight: c1Col.implicitHeight + 20
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: Theme.border

                        ColumnLayout {
                            id: c1Col
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                MaterialIcon { iconName: "delete_sweep"; pixelSize: 18; color: Theme.accent }
                                Text { text: "NixOS Store & Generations"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true; Layout.fillWidth: true }
                            }
                            Text {
                                text: root.cleanData && root.cleanData.nix ? (root.cleanData.nix.label + " (~" + ((root.cleanData.nix.reclaimableMb || 0) / 1024).toFixed(1) + " GB reclaimable)") : "Scanning generations…"
                                color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                            }
                            DialogButton {
                                text: "Clean & Optimise Store"
                                enabled: !root.runningOp
                                onClicked: root.runClean("nix", "Cleaning old generations & optimizing Nix store")
                            }
                        }
                    }

                    // 2. System Journals Card
                    Rectangle {
                        width: (parent.width - 12) / 2
                        implicitHeight: c2Col.implicitHeight + 20
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: Theme.border

                        ColumnLayout {
                            id: c2Col
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                MaterialIcon { iconName: "description"; pixelSize: 18; color: Theme.accent }
                                Text { text: "Systemd Journal Logs"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true; Layout.fillWidth: true }
                            }
                            Text {
                                text: root.cleanData && root.cleanData.journal ? (root.cleanData.journal.label + " (~" + (root.cleanData.journal.reclaimableMb || 0) + " MB reclaimable)") : "Scanning journal size…"
                                color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                            }
                            DialogButton {
                                text: "Vacuum Logs (<=100MB)"
                                enabled: !root.runningOp
                                onClicked: root.runClean("journal", "Vacuuming systemd journal logs to <=100MB")
                            }
                        }
                    }

                    // 3. User & App Caches Card
                    Rectangle {
                        width: (parent.width - 12) / 2
                        implicitHeight: c3Col.implicitHeight + 20
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: Theme.border

                        ColumnLayout {
                            id: c3Col
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                MaterialIcon { iconName: "folder_delete"; pixelSize: 18; color: Theme.accent }
                                Text { text: "Disposable Caches & Trash"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true; Layout.fillWidth: true }
                            }
                            Text {
                                text: root.cleanData && root.cleanData.caches ? ("Thumbnails, shaders, trash (~" + (root.cleanData.caches.totalMb || 0) + " MB)") : "Scanning caches…"
                                color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                            }
                            DialogButton {
                                text: "Purge Caches"
                                enabled: !root.runningOp
                                onClicked: root.runClean("caches", "Purging thumbnail, shader, and trash caches")
                            }
                        }
                    }

                    // 4. Memory & ZRAM Compaction Card
                    Rectangle {
                        width: (parent.width - 12) / 2
                        implicitHeight: c4Col.implicitHeight + 20
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: Theme.border

                        ColumnLayout {
                            id: c4Col
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                MaterialIcon { iconName: "memory"; pixelSize: 18; color: Theme.accent }
                                Text { text: "ZRAM & Memory Optimizer"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true; Layout.fillWidth: true }
                            }
                            Text {
                                text: "Compact ZRAM swap buffers and drop inactive kernel page cache."
                                color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                            }
                            DialogButton {
                                text: "Compact & Drop Caches"
                                enabled: !root.runningOp
                                onClicked: root.runClean("memory", "Compacting ZRAM swap and dropping inactive caches")
                            }
                        }
                    }
                }
            }

            // ── Process Sentinel & Top Tasks ──
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    SectionLabel { text: "Active Processes & Sentinel Monitor" }
                    Item { Layout.fillWidth: true }
                    DialogButton {
                        text: "Reap Zombies (" + SentinelService.zombieCount + ")"
                        visible: SentinelService.zombieCount > 0
                        onClicked: SentinelService.reap()
                    }
                }

                // Process Table
                ListView {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(320, count * 42)
                    clip: true
                    model: SentinelService.topCpu
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        implicitHeight: 38
                        radius: Theme.radiusMd
                        color: modelData.stat && modelData.stat.indexOf("Z") >= 0 ? Theme.withAlpha(Theme.error, 0.12)
                             : (modelData.cpu >= 70 ? Theme.withAlpha(Theme.warning, 0.12) : Theme.surface)
                        border.color: modelData.cpu >= 70 ? Theme.warning : Theme.border

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                            Text {
                                text: String(modelData.pid)
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                                Layout.preferredWidth: 60
                            }
                            Text {
                                text: modelData.comm || "task"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: (modelData.cpu || 0).toFixed(1) + "% CPU"
                                color: modelData.cpu >= 70 ? Theme.warning : Theme.textSecondary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                Layout.preferredWidth: 70
                            }
                            Text {
                                text: (modelData.rssMb || 0) + " MB"
                                color: Theme.textSecondary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                Layout.preferredWidth: 65
                            }
                            DialogButton {
                                text: "Freeze"
                                onClicked: SentinelService.stop(modelData.pid)
                            }
                            DialogButton {
                                text: "Kill"
                                onClicked: SentinelService.kill(modelData.pid)
                            }
                        }
                    }
                }
            }

            // ── Policies & Toggles ──
            ColumnLayout {
                Layout.fillWidth: true; spacing: 12
                SectionLabel { text: "Sentinel & AI Policies" }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: "Process Sentinel"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                        Text { text: "Monitor background tasks for runaway CPU, memory leaks, and unresponsive states."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    }
                    ToggleSwitch {
                        checked: SettingsBus.get("sentinel.enable", true)
                        onToggled: function(c) { root.bset("sentinel.enable", c) }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: "Silent Zombie Reaping"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                        Text { text: "Automatically clean up dead/defunct child processes in the background without prompting."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    }
                    ToggleSwitch {
                        checked: SettingsBus.get("sentinel.autoReapZombies", true)
                        onToggled: function(c) { root.bset("sentinel.autoReapZombies", c) }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: "3-Minute Auto-Kill Protection"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                        Text { text: "Automatically terminate un-whitelisted processes that sustain 3 consecutive runaway flags without progress."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    }
                    ToggleSwitch {
                        checked: SettingsBus.get("sentinel.autoKillRunaways", true)
                        onToggled: function(c) { root.bset("sentinel.autoKillRunaways", c) }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: "AI Crash Assistant"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                        Text { text: "Capture coredumps, service failures, OOM events, and GPU resets, offering root-cause AI fix recipes."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                    }
                    ToggleSwitch {
                        checked: SettingsBus.get("ai.crashAssist", true)
                        onToggled: function(c) { root.bset("ai.crashAssist", c) }
                    }
                }
            }

            Item { implicitHeight: 6 }
        }
    }
}
