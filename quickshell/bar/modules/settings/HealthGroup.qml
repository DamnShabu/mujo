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

    // The one number this page exists to move. It is the app's single hero
    // metric, so it gets size — not a ring, a badge and a sentence all
    // restating the same status, which is what it had.
    MujoCard {
        title: "System Health Sentinel"

        actions: RowLayout {
            spacing: 6
            DialogButton { text: "Scan"; enabled: !root.runningOp; onClicked: root.refreshAll() }
            DialogButton {
                text: "Optimize all"
                primary: true
                enabled: !root.runningOp
                onClicked: root.runClean("all", "Full System Optimization")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 18

            readonly property color tone: SentinelService.healthScore >= 85 ? Theme.success
                                        : (SentinelService.healthScore >= 60 ? Theme.warning : Theme.error)

            Text {
                text: String(SentinelService.healthScore)
                color: parent.tone
                font.family: Theme.fontMono
                font.pixelSize: 34
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    text: SentinelService.healthScore >= 90 ? "Everything is running normally"
                        : (SentinelService.healthScore >= 70 ? "Minor bottlenecks — worth a look"
                        : "Resource runaways need attention")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.weight: Font.DemiBold
                }

                Text {
                    text: {
                        var n = SentinelService.anomalies ? SentinelService.anomalies.length : 0
                        var s = n + (n === 1 ? " anomaly" : " anomalies")
                            + ", " + SentinelService.zombieCount
                            + (SentinelService.zombieCount === 1 ? " zombie" : " zombies")
                        if (root.cleanData && root.cleanData.totalReclaimableMb)
                            s += ", " + (root.cleanData.totalReclaimableMb / 1024).toFixed(1) + " GB reclaimable"
                        return s
                    }
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    // ── Maintenance output ────────────────────────────────────────────────────
    MujoCard {
        visible: root.runningOp || root.logLines.length > 0
        title: root.opLabel || "Maintenance"
        badgeText: root.runningOp ? "RUNNING" : (root.failedOp ? "FAILED" : "DONE")
        badgeColor: root.runningOp ? Theme.accent : (root.failedOp ? Theme.error : Theme.success)

        actions: RowLayout {
            spacing: 6
            DialogButton { text: "Cancel"; visible: root.runningOp; onClicked: if (root.runningOp) opProc.running = false }
            DialogButton {
                text: "Clear"
                visible: !root.runningOp && root.logLines.length > 0
                onClicked: root.logLines = []
            }
        }

        InsetPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 170
            accentBorder: root.failedOp ? Theme.error : (root.runningOp ? Theme.accent : Theme.border)

            ListView {
                id: logView
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                model: root.logLines
                boundsBehavior: Flickable.DragAndOvershootBounds
                onCountChanged: positionViewAtEnd()
                spacing: 1

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

            Spinner {
                anchors { right: parent.right; top: parent.top; margins: 10 }
                size: 13
                visible: root.runningOp
            }
        }
    }

    // ── Storage ───────────────────────────────────────────────────────────────
    // Four things you can reclaim is a list, not a two-by-two grid of identical
    // boxes. Each says how much it is holding and offers the one action.
    MujoCard {
        title: "Storage Reclamation & Cleaner"

        MujoSettingRow {
            iconName: "delete_sweep"
            title: "NixOS generations"
            description: root.cleanData && root.cleanData.nix
                ? root.cleanData.nix.label
                : "Counting old generations…"

            Text {
                text: root.cleanData && root.cleanData.nix
                    ? ((root.cleanData.nix.reclaimableMb || 0) / 1024).toFixed(1) + " GB" : "—"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }
            DialogButton {
                text: "Clean"
                enabled: !root.runningOp
                onClicked: root.runClean("nix", "Cleaning old generations & optimizing Nix store")
            }
        }

        MujoSettingRow {
            iconName: "description"
            title: "Systemd journals"
            description: root.cleanData && root.cleanData.journal
                ? root.cleanData.journal.label
                : "Measuring journal size…"

            Text {
                text: root.cleanData && root.cleanData.journal
                    ? (root.cleanData.journal.reclaimableMb || 0) + " MB" : "—"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }
            DialogButton {
                text: "Vacuum to 100 MB"
                enabled: !root.runningOp
                onClicked: root.runClean("journal", "Vacuuming systemd journal logs to <=100MB")
            }
        }

        MujoSettingRow {
            iconName: "folder_delete"
            title: "Disposable caches"
            description: "Thumbnails, shader caches and the trash."

            Text {
                text: root.cleanData && root.cleanData.caches
                    ? (root.cleanData.caches.totalMb || 0) + " MB" : "—"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }
            DialogButton {
                text: "Purge"
                enabled: !root.runningOp
                onClicked: root.runClean("caches", "Purging thumbnail, shader, and trash caches")
            }
        }

        MujoSettingRow {
            iconName: "memory"
            title: "ZRAM and page cache"
            description: "Compact the ZRAM swap buffers and drop inactive kernel page cache."

            DialogButton {
                text: "Compact"
                enabled: !root.runningOp
                onClicked: root.runClean("memory", "Compacting ZRAM swap and dropping inactive caches")
            }
        }
    }

    // ── Automation ────────────────────────────────────────────────────────────
    // SentinelService reads these three keys on every scan; an earlier
    // migration dropped their toggles, leaving the automation reachable only
    // through `mujo settings set`.
    MujoCard {
        title: "Sentinel Automation"

        SettingRow {
            path: "sentinel.enable"
            def: true
            kind: "toggle"
            iconName: "monitor_heart"
            title: "Process sentinel"
            description: "Watch background tasks for runaway CPU, memory leaks and unresponsive states."
        }

        SettingRow {
            path: "sentinel.autoReapZombies"
            def: true
            kind: "toggle"
            iconName: "pest_control"
            title: "Reap zombies silently"
            description: "Clean up defunct child processes in the background without asking."
            disabled: !SettingsBus.get("sentinel.enable", true)
        }

        SettingRow {
            path: "sentinel.autoKillRunaways"
            def: true
            kind: "toggle"
            iconName: "block"
            title: "Auto-kill runaways after 3 minutes"
            description: "Terminate un-whitelisted processes that sustain three consecutive runaway flags without progress."
            disabled: !SettingsBus.get("sentinel.enable", true)
        }
    }

    // ── Anomalies ─────────────────────────────────────────────────────────────
    MujoCard {
        title: "Process Sentinel & Anomaly Tracker"
        badgeText: SentinelService.problematicProcesses.length > 0
            ? SentinelService.problematicProcesses.length + " ANOMALIES" : "ALL CLEAN"
        badgeColor: SentinelService.problematicProcesses.length > 0 ? Theme.error : Theme.success

        actions: RowLayout {
            spacing: 6
            DialogButton {
                text: "Reap " + SentinelService.zombieCount + " zombies"
                visible: SentinelService.zombieCount > 0
                onClicked: SentinelService.reap()
            }
            IconButton { iconName: "refresh"; onClicked: SentinelService.refresh() }
        }

        Text {
            visible: SentinelService.problematicProcesses.length === 0
            text: "Every background process is inside its CPU and memory budget."
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Repeater {
            model: SentinelService.problematicProcesses

            delegate: ListRow {
                required property var modelData
                readonly property bool severe: modelData.warning || modelData.type === "cpu_runaway"
                border.color: severe ? Theme.withAlpha(Theme.error, 0.55) : Theme.border

                MaterialIcon {
                    iconName: modelData.type === "zombie" ? "pest_control"
                            : (modelData.type === "cpu_runaway" ? "speed"
                            : (modelData.type === "mem_hog" ? "memory" : "warning"))
                    pixelSize: 17
                    color: Theme.error
                }

                Text {
                    text: String(modelData.pid)
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.preferredWidth: 48
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: modelData.name || "Unknown"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: modelData.reason || ""
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                DialogButton { text: "Kill"; onClicked: SentinelService.killProcess(modelData.pid) }
            }
        }
    }
}
