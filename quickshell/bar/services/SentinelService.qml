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

    property int healthScore: 100
    property string healthStatus: "optimal" // "optimal", "warning", "critical"
    property var anomalies: []
    property var topCpu: []
    property var topMem: []
    property var gpu: null
    property int zombieCount: 0
    property var _warnedPids: ({}) // PID -> timestamp of last warning toast to avoid spamming

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

    function _runAction(act, pid, val) {
        actionProc.command = val ? ["mujo", "sentinel", "action", act, String(pid), String(val)]
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
                    sentinel.scanCompleted()

                    // Auto-reap zombies if enabled and present
                    if (sentinel.autoReapZombies && sentinel.zombieCount > 0 && !reapProc.running) {
                        reapProc.running = true
                    }

                    // Check for severe runaway processes to alert
                    sentinel._checkSevereAnomalies(sentinel.anomalies)
                } catch (e) {}
            }
        }
    }

    property Process reapProc: Process {
        command: ["mujo", "sentinel", "reap"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var r = JSON.parse(this.text)
                    if (r.reapedCount && r.reapedCount > 0) {
                        // Silent reap or low notification
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

    function _checkSevereAnomalies(list) {
        var now = Date.now()
        for (var i = 0; i < list.length; i++) {
            var a = list[i]
            if (a.type === "cpu_runaway" && a.cpu >= 80) {
                if (!sentinel._warnedPids[a.pid] || now - sentinel._warnedPids[a.pid] > 90000) {
                    sentinel._warnedPids[a.pid] = now
                    sentinel.anomalyDetected(a)
                    Notifications.notify(
                        "High CPU Usage: " + a.comm,
                        "Process (PID " + a.pid + ") is consuming " + a.cpu.toFixed(0) + "% CPU.",
                        "memory", "normal",
                        {
                            appName: "Sentinel",
                            actions: [
                                { text: "Freeze", invoke: function () { sentinel.stop(a.pid) } },
                                { text: "Kill", invoke: function () { sentinel.kill(a.pid) } },
                                { text: "Open Health", invoke: function () { SettingsBus.go("health") } }
                            ],
                            expire: 15
                        }
                    )
                }
            } else if (a.type === "mem_hog" && a.rssMb >= 4000) {
                if (!sentinel._warnedPids[a.pid] || now - sentinel._warnedPids[a.pid] > 120000) {
                    sentinel._warnedPids[a.pid] = now
                    sentinel.anomalyDetected(a)
                    Notifications.notify(
                        "High Memory Usage: " + a.comm,
                        "Process (PID " + a.pid + ") is holding " + (a.rssMb / 1024).toFixed(1) + " GB RAM.",
                        "memory", "normal",
                        {
                            appName: "Sentinel",
                            actions: [
                                { text: "Kill", invoke: function () { sentinel.kill(a.pid) } },
                                { text: "Open Health", invoke: function () { SettingsBus.go("health") } }
                            ],
                            expire: 15
                        }
                    )
                }
            }
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
