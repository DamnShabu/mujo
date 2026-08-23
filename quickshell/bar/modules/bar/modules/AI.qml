pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// AI advisor core (WP-08). Async, non-blocking wrapper around `mujo ai chat`
// (OpenAI-compatible completion; key from keyring, config from ai.* settings).
// One request in flight at a time via a single Process; a small pending queue is
// capped so at most 2 requests exist at once. 60s hard timeout, abortable.
//
// Permission model: this is a READ-ONLY advisor. It returns text; it never
// writes system/shell/settings state. Callers turn suggestions into explicit
// Apply actions using existing mechanisms.
QtObject {
    id: ai

    // Emitted when a request finishes. `id` is the value returned by send().
    signal replied(int id, string text)
    signal errored(int id, string message)

    // Fire-and-forget ask that surfaces the reply as a notification (used by the
    // `/` palette "Ask AI", which closes before the reply lands).
    property var _notifyIds: ({})
    function ask(prompt) {
        if (!prompt || prompt.trim() === "") return -1
        var id = ai.send([{ role: "user", content: prompt }])
        ai._notifyIds[id] = true
        Notifications.notify("Asking AI…", prompt, "neurology", "low", { appName: "AI", transient: true })
        return id
    }
    property Connections _notifyConn: Connections {
        target: ai
        function onReplied(id, text) {
            if (ai._notifyIds[id] === undefined) return
            delete ai._notifyIds[id]
            Notifications.notify("AI", text, "neurology", "normal",
                { appName: "AI", actions: [{ text: "Copy", invoke: function () { Quickshell.execDetached(["wl-copy", text]) } }] })
        }
        function onErrored(id, message) {
            if (ai._notifyIds[id] === undefined) return
            delete ai._notifyIds[id]
            Notifications.notify("AI failed", message, "error", "normal", { appName: "AI" })
        }
    }

    property int _seq: 0
    property var _queue: []          // [{ id, messages }]
    property int _activeId: -1
    property bool _discardExit: false
    readonly property bool busy: ai._activeId >= 0
    property string lastError: ""

    // Queue a completion. `messages` is an OpenAI-style array
    // [{role, content}, …]. Returns a request id used by replied/errored/abort.
    function send(messages) {
        if (!messages || messages.length === 0)
            return -1
        var id = ++ai._seq
        if ((ai._activeId >= 0 ? 1 : 0) + ai._queue.length >= 2) {
            Qt.callLater(function () { ai.errored(id, "AI is busy — try again in a moment") })
            return id
        }
        var q = ai._queue.slice()
        q.push({ id: id, messages: messages })
        ai._queue = q
        ai._pump()
        return id
    }

    // Cancel a queued or in-flight request.
    function abort(id) {
        if (id === ai._activeId) {
            ai._discardExit = true
            ai._timeout.stop()
            proc.running = false        // SIGTERM; onExited drains the queue
            ai.errored(id, "aborted")
        } else {
            ai._queue = ai._queue.filter(function (x) { return x.id !== id })
        }
    }

    function _pump() {
        if (ai._activeId >= 0 || ai._queue.length === 0)
            return
        var head = ai._queue[0]
        ai._queue = ai._queue.slice(1)
        ai._activeId = head.id
        proc._out = ""
        proc._err = ""
        proc.payload = JSON.stringify(head.messages)
        proc.sent = false
        proc.stdinEnabled = true
        proc.running = true
        ai._timeout.restart()
    }

    property Timer _timeout: Timer {
        interval: 60000
        onTriggered: {
            if (ai._activeId < 0)
                return
            var id = ai._activeId
            ai._discardExit = true
            proc.running = false
            ai.lastError = "request timed out (60s)"
            ai.errored(id, ai.lastError)
        }
    }

    property Process proc: Process {
        id: proc
        command: ["mujo", "ai", "chat"]
        property string payload: ""
        property bool sent: false
        property string _out: ""
        property string _err: ""
        stdout: StdioCollector { onStreamFinished: proc._out = this.text }
        stderr: StdioCollector { onStreamFinished: proc._err = this.text }
        onRunningChanged: {
            if (running && !sent) { write(payload); stdinEnabled = false; sent = true }
        }
        onExited: (code, status) => {
            if (ai._discardExit) { ai._discardExit = false; ai._activeId = -1; ai._pump(); return }
            var id = ai._activeId
            ai._activeId = -1
            ai._timeout.stop()
            if (code === 0 && proc._out.trim() !== "") {
                ai.replied(id, proc._out.trim())
            } else {
                var e = proc._err.trim() || "AI request failed"
                ai.lastError = e
                ai.errored(id, e)
            }
            ai._pump()
        }
    }
}
