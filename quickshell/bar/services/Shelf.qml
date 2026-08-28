pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Drag-in staging tray (WP-25) — the single source of truth for shelved items.
//
// Items are file references, not copies: dragging a file onto the edge strip
// (ShelfSurface) adds its path here; dragging one out onto a folder/app lets the
// consuming app perform the actual move/copy (plain uri-list rules). The model
// is in-memory; a spill-over JSON at ~/.local/state/qsshell/shelf.json restores
// it on shell restart (gated by shelf.restoreOnRestart).
//
// Views (ShelfSurface edge slide-out + ShelfButton bar popup) both render this
// same `items` model. The bar button/popup are visible only while count>0 or the
// popup is open, so a zero-item shelf never lingers (DONE-WHEN).
QtObject {
    id: shelf

    // ─── Settings-derived ──────────────────────────────────────────────────
    readonly property bool enabled: SettingsBus.get("shelf.enabled", true)
    readonly property string edge: SettingsBus.get("shelf.edge", "right")      // "left" | "right"
    readonly property real stripLength: SettingsBus.get("shelf.stripLength", 0.4) // frac of screen height
    readonly property bool restoreOnRestart: SettingsBus.get("shelf.restoreOnRestart", true)

    // ─── Model ─────────────────────────────────────────────────────────────
    // items: [{ path, name, missing:bool, isDir:bool }]
    property var items: []
    readonly property int count: items.length
    readonly property int cap: 50
    property bool _overflowWarned: false

    signal changed()                     // items mutated
    signal toggleRequested()             // bar popup toggle (shell.qml routes to focused screen)

    function _toast(msg) { Notifications.notify(msg, "", "inventory_2", "low", { transient: true }) }

    readonly property string statePath:
        (Quickshell.env("HOME") || "/tmp") + "/.local/state/qsshell/shelf.json"

    // ─── Path helpers ──────────────────────────────────────────────────────
    function _basename(p) {
        if (p.length > 1) p = p.replace(/\/+$/, "")   // trim trailing slash (dirs)
        var i = p.lastIndexOf("/")
        return i >= 0 ? p.substring(i + 1) : p
    }
    function _uriToPath(uri) {
        uri = uri.trim()
        if (uri.indexOf("file://") === 0) uri = uri.substring(7)  // drops host part too (file:///)
        try { uri = decodeURIComponent(uri) } catch (e) {}
        return uri
    }
    function _index(path) {
        for (var i = 0; i < items.length; i++) if (items[i].path === path) return i
        return -1
    }

    // ─── Mutations ─────────────────────────────────────────────────────────
    function addPath(path) {
        if (!path) return
        if (path.length > 1) path = path.replace(/\/+$/, "")
        if (_index(path) >= 0) return                          // dedupe by path
        if (items.length >= cap) {
            if (!_overflowWarned) { _overflowWarned = true; _toast("Shelf full — " + cap + " item max") }
            return
        }
        var arr = items.slice()
        arr.push({ path: path, name: _basename(path), missing: false, isDir: false })
        items = arr
        changed(); scheduleSave(); verify()
    }

    function addUri(uri) { addPath(_uriToPath(uri)) }

    // Add every file:// or absolute path entry from a dropped payload.
    function addUriList(text) {
        if (!text) return
        var lines = text.split(/[\r\n]+/)
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (!l) continue
            if (l.indexOf("file://") === 0) addUri(l)
            else if (l.charAt(0) === "/") addPath(l)
        }
    }

    function remove(path) {
        var arr = items.filter(function (it) { return it.path !== path })
        if (arr.length === items.length) return
        items = arr
        _overflowWarned = false
        changed(); scheduleSave()
    }

    function clear() {
        if (items.length === 0) return
        items = []
        _overflowWarned = false
        changed(); scheduleSave()
    }

    // Bar-button / IPC toggle → routed to the focused screen's popup by shell.qml.
    function toggle() { toggleRequested() }

    // ─── Per-item actions ──────────────────────────────────────────────────
    function open(path) {
        var i = _index(path)
        if (i < 0) return
        if (items[i].missing) { remove(path); _toast("File no longer exists — removed"); return }
        Quickshell.execDetached(["xdg-open", path])
    }
    function copyPath(path) {
        var i = _index(path)
        if (i < 0) return
        if (items[i].missing) { remove(path); _toast("File no longer exists — removed"); return }
        Quickshell.execDetached(["wl-copy", "--", path])
        _toast("Path copied")
    }
    function reveal(path) {
        var i = _index(path)
        if (i < 0) return
        if (items[i].missing) { remove(path); _toast("File no longer exists — removed"); return }
        var dir = items[i].isDir ? path : (function () {
            var j = path.lastIndexOf("/"); return j > 0 ? path.substring(0, j) : "/"
        })()
        Quickshell.execDetached(["xdg-open", dir])
    }

    // ─── Persistence ───────────────────────────────────────────────────────
    property Timer _saveTimer: Timer {
        interval: 250
        onTriggered: shelf._flush()
    }
    function scheduleSave() { _saveTimer.restart() }

    property Process _writeProc: Process {
        id: writeProc
        // atomic: write tmp then rename; mkdir -p the state dir first.
        command: ["sh", "-c",
            "d=$(dirname \"$1\"); mkdir -p \"$d\" && cat > \"$1.tmp\" && mv -f \"$1.tmp\" \"$1\"",
            "sh", shelf.statePath]
        property string payload: ""
        property bool sent: false
        onRunningChanged: {
            if (running && !sent) { write(payload); stdinEnabled = false; sent = true }
        }
    }
    function _flush() {
        if (writeProc.running) { _saveTimer.restart(); return }  // coalesce
        var out = { items: items.map(function (it) { return { path: it.path } }) }
        writeProc.payload = JSON.stringify(out)
        writeProc.sent = false
        writeProc.stdinEnabled = true
        writeProc.running = true
    }

    function _parseState(txt) {
        if (!shelf.restoreOnRestart) return
        try {
            var c = JSON.parse(txt || "{}")
            var arr = []
            var seen = {}
            var src = c.items || []
            for (var i = 0; i < src.length && arr.length < shelf.cap; i++) {
                var p = src[i] && src[i].path
                if (!p || seen[p]) continue
                seen[p] = true
                arr.push({ path: p, name: shelf._basename(p), missing: true, isDir: false })
            }
            shelf.items = arr
            if (arr.length) { shelf.changed(); shelf.verify() }
            else { shelf.changed() }
        } catch (e) { console.warn("Shelf: state parse error:", e) }
    }

    property FileView _stateFile: FileView {
        path: shelf.statePath
        watchChanges: true
        onFileChanged: if (!writeProc.running) shelf._parseState(text())
        onLoaded: shelf._parseState(text())
        onLoadFailed: function (err) {}           // no state yet — fresh shelf
    }

    // ─── Existence + type verify (one process over all paths) ──────────────
    // Marks each item missing/present and flags directories (for the icon).
    property Process _verifyProc: Process {
        id: verifyProc
        stdout: StdioCollector {
            onStreamFinished: {
                var present = {}          // path -> isDir
                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i]
                    if (!l) continue
                    var t = l.charAt(0)               // 'd' or 'f'
                    var p = l.substring(2)            // after "d\t"
                    present[p] = (t === "d")
                }
                var arr = shelf.items.slice()
                var dirty = false
                for (var j = 0; j < arr.length; j++) {
                    var has = present.hasOwnProperty(arr[j].path)
                    var isDir = has ? present[arr[j].path] : arr[j].isDir
                    if (arr[j].missing !== !has || arr[j].isDir !== isDir) {
                        arr[j] = { path: arr[j].path, name: arr[j].name, missing: !has, isDir: isDir }
                        dirty = true
                    }
                }
                if (dirty) { shelf.items = arr; shelf.changed() }
            }
        }
    }
    function verify() {
        if (items.length === 0 || verifyProc.running) return
        var script = "for p in \"$@\"; do if [ -d \"$p\" ]; then printf 'd\\t%s\\n' \"$p\"; elif [ -e \"$p\" ]; then printf 'f\\t%s\\n' \"$p\"; fi; done"
        var cmd = ["sh", "-c", script, "sh"]
        for (var i = 0; i < items.length; i++) cmd.push(items[i].path)
        verifyProc.command = cmd
        verifyProc.running = true
    }

    // After a drag-out, the consuming app may have MOVED the file (GTK same-fs
    // default). Re-stat: vanished ⇒ moved ⇒ drop it from the shelf; still there
    // ⇒ copy/cancelled ⇒ keep. (Drag.drop()'s action code is unreliable here.)
    property Process _restatProc: Process {
        id: restatProc
        property string checkPath: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.indexOf("GONE") >= 0) shelf.remove(restatProc.checkPath)
            }
        }
    }
    function reconcileAfterDrag(path) {
        if (restatProc.running) return
        restatProc.checkPath = path
        restatProc.command = ["sh", "-c", "[ -e \"$1\" ] || echo GONE", "sh", path]
        restatProc.running = true
    }
}
