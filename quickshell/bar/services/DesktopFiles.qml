pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ~/Desktop as the desktop's item model.
//
// The filesystem is the source of truth for what exists; this service only
// mirrors it and asks the mujo CLI to change it. Grid slots live in a separate
// state file the CLI owns, so nothing here ever writes UI metadata into the
// user's own files.
//
// Quickshell 0.3 has no directory watcher — FileView watches single files only —
// so freshness comes from a poll plus an immediate refresh after every mutation
// we cause. External changes therefore appear within one poll interval; changes
// made here appear at once.
QtObject {
    id: files

    readonly property string dir: (Quickshell.env("HOME") || "/tmp") + "/Desktop"

    // [{ name, isDir, size, mtime }], folders first then case-insensitive by name
    property var items: []
    // { name: { col, row } } — grid slots for items we have already placed
    property var positions: ({})
    property bool loaded: false

    signal reloaded()
    signal failed(string message)

    // ponytail: 2s poll. Upgrade path is an `inotifywait -m` Process feeding
    // refresh(), worth it only if the latency on externally-created files
    // actually annoys someone.
    readonly property int pollInterval: 2000

    function refresh() { listProc.running = true }

    property Process _listProc: Process {
        id: listProc
        command: ["mujo", "desktop", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    files.items = d.items || []
                    files.positions = d.positions || ({})
                    files.loaded = true
                    files.reloaded()
                } catch (e) {
                    // A half-written listing is not worth a toast — the next poll
                    // will be clean. It is worth a log line, because a listing that
                    // never parses is otherwise indistinguishable from an empty
                    // desktop, and that silence hides real breakage.
                    console.warn("DesktopFiles: could not parse listing:", e)
                }
            }
        }
    }

    property Timer _poll: Timer {
        interval: files.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: files.refresh()
    }

    // ─── Mutations ────────────────────────────────────────────────────────────
    // One Process, serialised through a queue. Desktop edits are one-at-a-time
    // by nature (you rename one icon at a time), so the queue is a safety net
    // for a double-click, not a throughput concern.
    property var _queue: []
    property bool _busy: false

    function _run(args) {
        var q = files._queue.slice()
        q.push(args)
        files._queue = q
        files._pump()
    }

    function _pump() {
        if (files._busy || files._queue.length === 0) return
        var next = files._queue[0]
        files._queue = files._queue.slice(1)
        files._busy = true
        mutateProc.command = next
        mutateProc.running = true
    }

    property Process _mutateProc: Process {
        id: mutateProc
        stderr: StdioCollector {
            onStreamFinished: {
                var msg = this.text.trim()
                if (msg !== "") files.failed(msg)
            }
        }
        onExited: {
            files._busy = false
            files.refresh()
            files._pump()
        }
    }

    function createFolder() { files._run(["mujo", "desktop", "mkdir"]) }
    function createFile() { files._run(["mujo", "desktop", "new-file"]) }
    function rename(oldName, newName) {
        if (!oldName || !newName || oldName === newName) return
        files._run(["mujo", "desktop", "rename", oldName, newName])
    }
    function trash(names) {
        if (!names || names.length === 0) return
        files._run(["mujo", "desktop", "trash"].concat(names))
    }
    function open(name) { Quickshell.execDetached(["mujo", "desktop", "open", name]) }
    function openTerminal() { Quickshell.execDetached(["mujo", "desktop", "terminal"]) }

    // ─── Clipboard ────────────────────────────────────────────────────────────
    // The system clipboard, in the x-special/gnome-copied-files format every GTK
    // file manager reads — so a desktop copy pastes into Nautilus or Thunar and
    // a copy made there pastes onto the desktop. `cutNames` is only the local
    // hint used to fade the icons; the clipboard is the real state, and another
    // app taking the selection is what clears it.
    property var cutNames: []

    function copyToClipboard(names) {
        if (!names || names.length === 0) return
        files.cutNames = []
        files._run(["mujo", "desktop", "copy"].concat(names))
    }
    function cutToClipboard(names) {
        if (!names || names.length === 0) return
        files.cutNames = names.slice()
        files._run(["mujo", "desktop", "cut"].concat(names))
    }
    function paste() {
        files.cutNames = []
        files._run(["mujo", "desktop", "paste"])
    }

    // A drop from another application: text/uri-list, copied or moved.
    function importUris(mode, uris) {
        if (!uris || uris.length === 0) return
        files._run(["mujo", "desktop", "import", mode].concat(uris))
    }

    // Dropping items onto a desktop folder.
    function moveInto(folder, names) {
        if (!folder || !names || names.length === 0) return
        files._run(["mujo", "desktop", "into", folder].concat(names))
    }

    // ─── Properties ───────────────────────────────────────────────────────────
    // One outstanding request at a time; the dialog only ever shows one item.
    signal infoReady(var info)

    function requestInfo(name) {
        if (!name) return
        infoProc.running = false
        infoProc.command = ["mujo", "desktop", "info", name]
        infoProc.running = true
    }

    property Process _infoProc: Process {
        id: infoProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { files.infoReady(JSON.parse(this.text)) }
                catch (e) { files.failed("could not read item properties") }
            }
        }
    }

    // One write for a whole relayout. Placing icons one call at a time meant a
    // process per icon racing on the same file, which is how the slot store got
    // corrupted; the CLI now locks, and this keeps the common case to one call.
    function setPositions(map) {
        if (!map) return
        var names = Object.keys(map)
        if (names.length === 0) return
        var p = {}
        for (var k in files.positions) p[k] = files.positions[k]
        for (var i = 0; i < names.length; i++) p[names[i]] = map[names[i]]
        files.positions = p
        Quickshell.execDetached(["mujo", "desktop", "pos-batch", JSON.stringify(map)])
    }
}
