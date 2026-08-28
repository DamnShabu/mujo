import QtQuick
import Quickshell
import Quickshell.Io

// Multi-Source Crash Watcher & Diagnostic Dispatcher.
// Follows `mujo crash stream` to detect:
// 1. systemd-coredump coredumps
// 2. systemd service unit failures
// 3. systemd-oomd / kernel Out-Of-Memory kills
// 4. amdgpu GPU resets / ring timeouts
//
// Triggers desktop notifications with [Diagnose & Fix] and [Ask AI],
// and dispatches context to CrashFixModal.
QtObject {
    id: cw

    readonly property bool enabled: SettingsBus.get("ai.crashAssist", true)
    readonly property bool aiAllowed: SettingsBus.get("ai.allowCrashData", false)

    property var _lastSeen: ({})   // Comm/ID -> last seen timestamp for 60s deduplication
    property var activeCrash: null // Currently active crash object for modals

    signal crashReported(var crash)

    property int _backoff: 1000
    property Timer _retry: Timer {
        interval: cw._backoff
        onTriggered: if (cw.enabled) cw._watch.running = true
    }

    property Process _watch: Process {
        command: ["mujo", "crash", "stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => cw._onLine(line)
        }
        onExited: {
            if (!cw.enabled) return
            cw._retry.interval = cw._backoff
            cw._retry.restart()
            cw._backoff = Math.min(cw._backoff * 2, 30000)
        }
    }

    Component.onCompleted: if (cw.enabled) cw._watch.running = true
    onEnabledChanged: {
        if (cw.enabled) cw._watch.running = true
        else { cw._retry.stop(); cw._watch.running = false }
    }

    function _onLine(line) {
        cw._backoff = 1000
        if (!line || line.trim() === "") return
        var e
        try { e = JSON.parse(line) } catch (err) { return }
        if (!e || !e.type) return

        var comm = e.comm || "Program"
        var idKey = (e.type + ":" + (e.id || comm))
        var now = Date.now()
        if (cw._lastSeen[idKey] && now - cw._lastSeen[idKey] < 45000) return
        cw._lastSeen[idKey] = now
        cw.activeCrash = e
        cw.crashReported(e)
        cw._notifyCrash(e)
    }

    function _notifyCrash(e) {
        var comm = e.comm || "Program"
        var desc = e.summary || "The application closed unexpectedly."
        var actions = [
            {
                text: "Diagnose & Fix",
                invoke: function () {
                    cw.activeCrash = e
                    Quickshell.execDetached(["qs", "-p", "/etc/xdg/quickshell/bar/shell.qml", "ipc", "call", "crashFix", "open", JSON.stringify(e)])
                }
            },
            {
                text: "View details",
                invoke: function () { cw._runInfo(e.type, e.id || e.pid || comm) }
            }
        ]

        if (cw.aiAllowed) {
            actions.push({
                text: "Ask AI",
                invoke: function () { cw._runAiDiagnose(e.type, e.id || e.pid || comm) }
            })
        }

        Notifications.notify(
            comm + (e.type === "unit" ? " failed" : (e.type === "oom" ? " OOM killed" : " crashed")),
            desc,
            e.type === "gpu" ? "videogame_asset" : (e.type === "oom" ? "memory" : "error"),
            "critical",
            { appName: "Crash", actions: actions, expire: 25 }
        )
    }

    // ── Raw Details ──
    property Process _infoProc: Process {
        property string targetType: ""
        property string targetId: ""
        command: ["mujo", "crash", "info", targetType, targetId]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    Notifications.notify(
                        (d.comm || "Crash") + " — diagnostic log",
                        d.raw || "(no detailed log captured)",
                        "bug_report", "normal", { appName: "Crash" }
                    )
                } catch (e) {
                    Notifications.notify("Crash Log", this.text || "No details", "bug_report", "normal", { appName: "Crash" })
                }
            }
        }
    }

    function _runInfo(type, id) {
        _infoProc.targetType = type
        _infoProc.targetId = String(id || "")
        _infoProc.running = true
    }

    // ── Ask AI ──
    property Process _aiDiagnoseProc: Process {
        property string targetType: ""
        property string targetId: ""
        command: ["mujo", "crash", "diagnose", targetType, targetId]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(this.text)
                    var msg = (res.summary || "") + (res.rootCause ? ("\n\nRoot Cause: " + res.rootCause) : "")
                    Notifications.notify(
                        "AI Crash Diagnosis",
                        msg,
                        "neurology", "normal",
                        {
                            appName: "Crash",
                            actions: [{ text: "Copy", invoke: function () { Quickshell.execDetached(["wl-copy", msg]) } }]
                        }
                    )
                } catch (e) {
                    Notifications.notify("AI Crash Diagnosis", this.text || "Analysis finished.", "neurology", "normal", { appName: "Crash" })
                }
            }
        }
    }

    function _runAiDiagnose(type, id) {
        Notifications.notify("Analyzing crash with AI…", "Investigating logs and stacktrace...", "neurology", "low", { appName: "Crash", transient: true })
        _aiDiagnoseProc.targetType = type
        _aiDiagnoseProc.targetId = String(id || "")
        _aiDiagnoseProc.running = true
    }
}
