import QtQuick
import Quickshell
import Quickshell.Io

// Crash detection + assistance (WP-09). Follows the systemd-coredump journal
// stream; each coredump becomes a critical notification with [View details]
// (sanitized `coredumpctl info`) and, when the user consents via
// ai.allowCrashData, [Ask AI] (suggestions rendered as copyable commands, never
// executed). Gated by ai.crashAssist (default on). Needs the user in the
// systemd-journal group; journalctl/coredumpctl come from `systemd` on PATH.
// Instantiated once by shell.qml so it stays alive.
QtObject {
    id: cw

    readonly property bool enabled: SettingsBus.get("ai.crashAssist", true)
    readonly property bool aiAllowed: SettingsBus.get("ai.allowCrashData", false)

    property var _lastSeen: ({})   // COMM -> last-seen ms, for the 60s dedupe

    // Follow only NEW coredump entries (-n 0). -o json → one object per line.
    // journalctl -f should never exit on its own; if it does (journald restart,
    // stream death), respawn with exponential backoff so crash detection
    // self-heals instead of silently going dead for the rest of the session.
    property int _backoff: 1000
    property Timer _retry: Timer {
        interval: cw._backoff
        onTriggered: if (cw.enabled) cw._watch.running = true
    }
    property Process _watch: Process {
        command: ["journalctl", "-q", "-f", "-n", "0", "-o", "json",
                  "MESSAGE_ID=fc2e22bc6ee647b6b90729ab34a250b1"]
        stdout: SplitParser { splitMarker: "\n"; onRead: line => cw._onLine(line) }
        onExited: {
            if (!cw.enabled) return   // intentional stop (feature disabled)
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
        cw._backoff = 1000   // healthy stream → reset backoff
        var e
        try { e = JSON.parse(line) } catch (err) { return }
        var comm = e.COREDUMP_COMM || e._COMM || "A program"
        var pid = String(e.COREDUMP_PID || e._PID || "")
        var now = Date.now()
        if (cw._lastSeen[comm] && now - cw._lastSeen[comm] < 60000) return
        cw._lastSeen[comm] = now
        cw._notifyCrash(comm, pid)
    }

    function _notifyCrash(comm, pid) {
        var actions = [{ text: "View details", invoke: function () { cw._runInfo(cw._detail, comm, pid) } }]
        if (cw.aiAllowed)
            actions.push({ text: "Ask AI", invoke: function () { cw._runInfo(cw._aiInfo, comm, pid) } })
        // [Dismiss] is the toast's built-in close button.
        Notifications.notify(comm + " crashed",
            "The application closed unexpectedly (a coredump was captured).",
            "error", "critical",
            { appName: "Crash", actions: actions, expire: 20 })
    }

    // coredumpctl needs the pid when available, else the COMM (latest dump).
    function _runInfo(proc, comm, pid) {
        proc.comm = comm
        proc.command = pid ? ["coredumpctl", "info", pid] : ["coredumpctl", "info", comm]
        proc.running = true
    }

    // Strip the Environment: block (may hold secrets) and cap the length.
    function _sanitize(txt) {
        var lines = (txt || "").split("\n"), out = []
        for (var i = 0; i < lines.length; i++) {
            if (/^\s*Environment:/.test(lines[i])) {
                while (i + 1 < lines.length && /^\s+\S/.test(lines[i + 1])) i++
                out.push("    Environment: (hidden)")
                continue
            }
            out.push(lines[i])
        }
        var s = out.join("\n")
        return s.length > 1500 ? s.slice(0, 1500) + "\n…(truncated)" : s
    }

    // ── View details ──
    property Process _detail: Process {
        property string comm: ""
        stdout: StdioCollector {
            onStreamFinished: Notifications.notify(_detail.comm + " — crash details",
                cw._sanitize(this.text || "(no coredump info)"), "bug_report", "normal", { appName: "Crash" })
        }
    }

    // ── Ask AI (gated by ai.allowCrashData) ──
    property int _aiReq: -1
    property Process _aiInfo: Process {
        property string comm: ""
        stdout: StdioCollector { onStreamFinished: cw._sendToAI(this.text) }
    }
    function _sendToAI(txt) {
        var msgs = [
            { role: "system", content: "You are a Linux troubleshooting assistant. A program crashed and produced a coredump. From the sanitized crash info, give a short plain-language explanation, then up to 3 concrete shell commands (each on its own line) the user could run to investigate or fix it. The commands have NOT been run." },
            { role: "user", content: cw._sanitize(txt || "") }
        ]
        cw._aiReq = AI.send(msgs)
    }
    property Connections _aiConn: Connections {
        target: AI
        function onReplied(id, text) {
            if (id !== cw._aiReq) return
            cw._aiReq = -1
            Notifications.notify("AI crash suggestion", text, "neurology", "normal",
                { appName: "Crash", actions: [{ text: "Copy", invoke: function () { Quickshell.execDetached(["wl-copy", text]) } }] })
        }
        function onErrored(id, message) {
            if (id !== cw._aiReq) return
            cw._aiReq = -1
            Notifications.notify("AI crash suggestion failed", message, "error", "normal", { appName: "Crash" })
        }
    }
}
