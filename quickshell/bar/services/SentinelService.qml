pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Process Sentinel & Resource Monitor Singleton.
// Performs periodic low-overhead scans of CPU, RAM, VRAM/GPU, and zombie tasks.
// Provides tiered automation:
// - Tier 1: Silently reaps harmless defunct/zombie child processes.
// - Tier 2: Alerts user about runaway apps with one-click Freeze / Kill / Renice actions.
QtObject {
    id: sentinel

    readonly property bool enabled: SettingsBus.get("sentinel.enable", true)
    readonly property bool autoReapZombies: SettingsBus.get("sentinel.autoReapZombies", true)
    readonly property bool autoKillRunaways: SettingsBus.get("sentinel.autoKillRunaways", true)

    property int healthScore: 100
    property string healthStatus: "optimal" // "optimal", "warning", "critical"
    property var anomalies: []
    property var problematicProcesses: []
    property var terminatedHistory: []
    property var topCpu: []
    property var topMem: []
    property var gpu: null
    property int zombieCount: 0
    property int orphanCount: 0
    property var activeFlags: ({})
    property var autoKilled: []
    property var _warnedPids: ({})

    signal scanCompleted()
    signal anomalyDetected(var anomaly)

    function refresh() {
        if (!scanProc.running) scanProc.running = true
    }

    function kill(pid) { _runAction("kill", pid) }
    function term(pid) { _runAction("term", pid) }
    function stop(pid) { _runAction("stop", pid) }
    function cont(pid) { _runAction("cont", pid) }
    function renice(pid, val) { _runAction("renice", pid, val) }
    function reap() { reapProc.running = true }

    function dismissTerminated(pid) {
        var a = []
        for (var i = 0; i < sentinel.terminatedHistory.length; i++) {
            if (sentinel.terminatedHistory[i].pid !== pid) {
                a.push(sentinel.terminatedHistory[i])
            }
        }
        sentinel.terminatedHistory = a
        sentinel._recomputeProblematic()
    }

    function clearTerminatedHistory() {
        sentinel.terminatedHistory = []
        sentinel._recomputeProblematic()
    }

    function _runAction(act, pid, val) {
        // `val !== undefined`, not `val`: renice(pid, 0) is a real call -- reset
        // to normal priority -- and a truthiness test dropped the argument, so
        // it would have run `renice -n "" -p <pid>` and failed. kill/term/stop/
        // cont pass no value at all and still take the short form.
        actionProc.command = val !== undefined
            ? ["mujo", "sentinel", "action", act, String(pid), String(val)]
            : ["mujo", "sentinel", "action", act, String(pid)]
        actionProc.running = true
    }

    property Process scanProc: Process {
        command: ["mujo", "sentinel", "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    sentinel.healthScore = d.healthScore !== undefined ? d.healthScore : 100
                    sentinel.healthStatus = d.status || "optimal"
                    sentinel.anomalies = d.anomalies || []
                    sentinel.topCpu = d.topCpu || []
                    sentinel.topMem = d.topMem || []
                    sentinel.gpu = d.gpu || null
                    sentinel.zombieCount = d.zombieCount || 0
                    sentinel.orphanCount = d.orphanCount || 0
                    sentinel.activeFlags = d.activeFlags || ({})
                    sentinel.autoKilled = d.autoKilled || []

                    // Auto-reap zombies and orphaned processes if enabled and present
                    if (sentinel.autoReapZombies && (sentinel.zombieCount > 0 || sentinel.orphanCount > 0) && !reapProc.running) {
                        reapProc.running = true
                    }

                    // Build unified problematicProcesses list without desktop notifications
                    sentinel._updateProblematicProcesses(d)
                    sentinel.scanCompleted()

                    // Signal anomalies for internal listeners without showing notification toasts
                    if (sentinel.anomalies && sentinel.anomalies.length > 0) {
                        for (var i = 0; i < sentinel.anomalies.length; i++) {
                            sentinel.anomalyDetected(sentinel.anomalies[i])
                        }
                    }
                } catch (e) {}
            }
        }
    }

    function _updateProblematicProcesses(d) {
        if (d.autoKilled && d.autoKilled.length > 0) {
            var hist = sentinel.terminatedHistory.slice()
            for (var k = 0; k < d.autoKilled.length; k++) {
                var ak = d.autoKilled[k]
                var exists = false
                for (var h = 0; h < hist.length; h++) {
                    if (hist[h].pid === ak.pid && hist[h].timestamp === ak.timestamp) {
                        exists = true
                        break
                    }
                }
                if (!exists) {
                    hist.unshift({
                        pid: ak.pid,
                        comm: ak.comm || "task",
                        type: ak.type || "auto_killed",
                        label: "Auto-Killed",
                        details: "Terminated after 3 min unresponsive runaway resource usage",
                        status: "terminated",
                        cpu: 0,
                        rssMb: 0,
                        reason: ak.reason || "sustained 3 flags without progress",
                        timestamp: ak.timestamp ? (ak.timestamp * 1000) : Date.now()
                    })
                }
            }
            if (hist.length > 20) hist = hist.slice(0, 20)
            sentinel.terminatedHistory = hist
        }

        sentinel._recomputeProblematic()
    }

    function _recomputeProblematic() {
        var list = []
        var flags = sentinel.activeFlags || ({})
        var anomalies = sentinel.anomalies || []

        // Process active anomalies
        for (var i = 0; i < anomalies.length; i++) {
            var a = anomalies[i]
            var pidStr = String(a.pid)
            var flagInfo = flags[pidStr] || null
            var flagCount = flagInfo ? (flagInfo.count || 0) : 0
            var isWarning = flagCount >= 2

            var details = ""
            if (a.type === "cpu_runaway") {
                details = "Consuming " + (a.cpu ? a.cpu.toFixed(1) : "0") + "% CPU"
            } else if (a.type === "mem_hog") {
                details = "Holding " + (a.rssMb ? (a.rssMb >= 1024 ? (a.rssMb / 1024).toFixed(1) + " GB" : a.rssMb + " MB") : "0 MB") + " RAM"
            } else if (a.type === "zombie") {
                details = "Defunct zombie process awaiting parent cleanup"
            } else if (a.type === "orphaned_process") {
                details = "Orphaned background process running without parent"
            } else if (a.type === "d_state") {
                details = "Uninterruptible disk wait state"
            } else {
                details = a.label || "Resource anomaly"
            }

            if (isWarning) {
                details += " · Sustained runaway (" + flagCount + "m)"
            }

            list.push({
                pid: a.pid,
                ppid: a.ppid,
                comm: a.comm || "task",
                type: a.type || "anomaly",
                label: isWarning ? ("Runaway (" + flagCount + "m)") : (a.label || "Anomaly"),
                details: details,
                cpu: a.cpu || 0,
                rssMb: a.rssMb || 0,
                mem: a.mem || 0,
                stat: a.stat || "",
                status: "active",
                flagCount: flagCount,
                warning: isWarning,
                timestamp: Date.now()
            })
        }

        // Append terminated history items (if not already present as active)
        for (var j = 0; j < sentinel.terminatedHistory.length; j++) {
            var th = sentinel.terminatedHistory[j]
            var found = false
            for (var m = 0; m < list.length; m++) {
                if (list[m].pid === th.pid && list[m].status === "active") {
                    found = true
                    break
                }
            }
            if (!found) {
                list.push(th)
            }
        }

        sentinel.problematicProcesses = list
    }

    property Process reapProc: Process {
        command: ["mujo", "sentinel", "reap"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var r = JSON.parse(this.text)
                    if (r.reapedCount && r.reapedCount > 0) {
                        sentinel.refresh()
                    }
                } catch (e) {}
            }
        }
    }

    property Process actionProc: Process {
        onExited: function (code) {
            sentinel.refresh()
        }
    }

    property Timer _pollTimer: Timer {
        interval: 10000
        running: sentinel.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: sentinel.refresh()
    }
}
