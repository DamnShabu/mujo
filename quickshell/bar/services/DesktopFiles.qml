pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// ~/Desktop as the desktop's item model.
//
// The filesystem is the source of truth for what exists; this service only
// mirrors it and asks the mujo CLI to change it. Grid slots live in a separate
// state file the CLI owns, so nothing here ever writes UI metadata into the
// user's own files.
//
// Every mutation we cause refreshes immediately (see _mutateProc.onExited), so
// the watcher below exists only for *external* changes — a download landing on
// the desktop, a file manager moving something in. Qt's FolderListModel is
// backed by QFileSystemWatcher (inotify), which is why this no longer needs the
// 2s `mujo desktop list` poll that used to run for the life of the session:
// that was 30 forks a minute of bash+find+jq to re-read a directory that
// changes a couple of times an hour. A slow backstop poll stays, because a file
// being *written in place* changes its size without changing the directory.
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

    // Backstop only — the FolderListModel watcher below catches everything that
    // changes the directory itself. This covers in-place writes, which change a
    // file's size without touching the directory entry.
    readonly property int pollInterval: 30000

    function refresh() { listProc.running = true }

    // Directory watcher (QFileSystemWatcher/inotify under the hood). Any
    // external create/delete/rename in ~/Desktop lands here within a frame, so
    // new items now appear faster than the old 2s poll managed while costing
    // nothing when the desktop is idle.
    property FolderListModel _watch: FolderListModel {
        folder: "file://" + files.dir
        showDirs: true
        showFiles: true
        showHidden: false
        // Sorting is mujo's job; this model is only ever used as a change
        // signal, never read for its rows.
        sortField: FolderListModel.Unsorted
        onCountChanged: watchDebounce.restart()
    }

    // A single external operation (an unzip, a multi-file move) fires many
    // watcher events; collapse them into one listing.
    property Timer _watchDebounce: Timer {
        id: watchDebounce
        interval: 150
        onTriggered: files.refresh()
    }

    property Timer _poll: Timer {
        interval: files.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: files.refresh()
    }

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
