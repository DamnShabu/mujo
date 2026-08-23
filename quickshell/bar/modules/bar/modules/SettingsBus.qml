pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Unified shell settings store + in-process navigation bus.
//
// Store: one JSON file — ~/.config/qsshell/settings.json — the single source of
// truth for every namespaced shell setting (bar.*, island.*, notifications.*,
// weather.*, apps.*, ai.*, idle.*, lock.*, cava.*, backup.*, motion.*, …). The
// color palette (theme.json, `mujo theme`) and wallpaper (wallpaper.json) keep
// their own files; this store owns everything else.
//
//   read   get(path, fallback)      dotted-path walk over the merged snapshot,
//                                    falling back to defaults[path] then fallback
//   write  set(path, value)         optimistic in-memory update + debounced,
//                                    atomic whole-file write via `mujo settings
//                                    write` (stdin). value may be any JSON type.
//
// FileView watches the file so external writes (`mujo settings set` from the CLI
// or the `/` palette) reload live. Corrupt JSON on disk falls back to defaults
// and emits warning() — surfaced as a toast by the notification center (WP-04);
// until then it is a console warning.
//
// Nav bus (unchanged): go(key)/navigate(key) let panels request Settings
// navigation without reaching through parents (Overview cards, etc.).
QtObject {
    id: bus

    // ─── Navigation bus ────────────────────────────────────────────────────
    signal navigate(string key)
    function go(key) { navigate(key) }

    // ─── Store: signals + state ────────────────────────────────────────────
    signal warning(string msg)
    signal loaded()

    readonly property string configPath:
        (Quickshell.env("HOME") || "/tmp") + "/.config/qsshell/settings.json"

    // Flat map of dotted-path → default. get() consults this per-leaf, so a key
    // listed here is readable everywhere without seeding the on-disk file. Each
    // owning WP appends its namespace as it lands.
    readonly property var defaults: ({
        "motion.reduce": false,
        "bar.blurAmount": 0,
        "bar.height": 34,
        "bar.margin": 7,
        "bar.spacing": 6,
        "bar.opacity": 1,
        "bar.position": "top",
        "bar.autoHide": false,
        "bar.scrollActions": true,
        "bar.rightModules": ["llm", "network", "bluetooth", "volume", "notifications", "tray", "session"],
        "bar.hiddenMonitors": [],
        "bar.trayHidden": [],
        "bar.trayRecolour": false,
        "island.enabled": true,
        "island.modules": ["clock", "media", "weather"],
        "island.maxWidth": 520,
        "island.radius": 18,
        "island.opacity": 1,
        "island.background": "",
        "island.yOffset": 0,
        "island.autoExpandMs": 4000,
        "island.expandOnNotify": true,
        "cava.enabled": false,
        "cava.style": "bars",
        "cava.color": "",
        "cava.opacity": 0.85,
        "cava.height": 0.18,
        "cava.position": "bottom",
        "cava.reflection": true,
        "idle.enabled": true,
        "idle.rules": [
            { "timeoutSec": 180, "action": "dim", "inhibitWhenAudio": true },
            { "timeoutSec": 300, "action": "screenOff", "returnAction": "screenOn" },
            { "timeoutSec": 600, "action": "lock" },
            { "timeoutSec": 1200, "action": "suspend" }
        ],
        "lock.enable": true,
        "launcher.enableDangerousActions": false,
        "backup.enabled": false,
        "ai.provider": "ollama",
        "ai.baseUrl": "http://127.0.0.1:11434/v1",
        "ai.maxTokens": 1024,
        "ai.crashAssist": true,
        "ai.allowShellContext": false,
        "ai.allowCrashData": false,
        "ai.confirmActions": true
    })

    property var values: ({})   // parsed settings.json tree (raw on disk)

    // ─── Read ──────────────────────────────────────────────────────────────
    function get(path, fallback) {
        var parts = path.split(".")
        var o = bus.values
        var ok = true
        for (var i = 0; i < parts.length; i++) {
            if (o === null || typeof o !== "object") { ok = false; break }
            o = o[parts[i]]
            if (o === undefined) { ok = false; break }
        }
        if (ok && o !== undefined && o !== null) return o
        if (bus.defaults[path] !== undefined) return bus.defaults[path]
        return fallback
    }

    // ─── Write (optimistic + debounced atomic) ─────────────────────────────
    function set(path, value) {
        var parts = path.split(".")
        // Deep-clone so bindings on `values` re-evaluate (assigning a mutated
        // in-place object doesn't notify).
        var root = JSON.parse(JSON.stringify(bus.values || {}))
        var o = root
        for (var i = 0; i < parts.length - 1; i++) {
            if (o[parts[i]] === undefined || o[parts[i]] === null || typeof o[parts[i]] !== "object")
                o[parts[i]] = ({})
            o = o[parts[i]]
        }
        o[parts[parts.length - 1]] = value
        bus.values = root
        bus._dirty = true
        writeTimer.restart()
    }

    property bool _dirty: false

    function _flush() {
        if (!bus._dirty) return
        if (writeProc.running) { writeTimer.restart(); return }
        writeProc.payload = JSON.stringify(bus.values)
        writeProc.sent = false
        writeProc.stdinEnabled = true
        bus._dirty = false
        writeProc.running = true
    }

    property Timer _writeTimer: Timer {
        id: writeTimer
        interval: 350
        onTriggered: bus._flush()
    }

    property Process _writeProc: Process {
        id: writeProc
        command: ["mujo", "settings", "write"]
        property string payload: ""
        property bool sent: false
        onRunningChanged: {
            if (running && !sent) { write(payload); stdinEnabled = false; sent = true }
            else if (!running && bus._dirty) bus._flush()  // coalesce changes made mid-write
        }
    }

    property FileView _cfg: FileView {
        path: bus.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            // ponytail: while our own write is in flight (or unwritten edits are
            // pending) ignore the disk echo — QML holds the newest snapshot.
            // External CLI edits are adopted only when quiescent.
            if (writeProc.running || bus._dirty) return
            try {
                bus.values = JSON.parse(text() || "{}")
            } catch (e) {
                bus.values = ({})
                bus.warning("Settings file was invalid JSON — using defaults.")
                console.warn("SettingsBus: parse error:", e)
            }
            bus.loaded()
        }
        onLoadFailed: function(err) { bus.values = ({}) }  // not created yet
    }
}
