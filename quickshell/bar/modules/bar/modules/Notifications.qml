pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire

// The shell's notification daemon + state (WP-04). Runs Quickshell's
// NotificationServer in-process (swayosd stays for volume/brightness OSD; every
// libnotify notification routes here). Exposes:
//   popups   live toasts (rendered by NotificationPopup), auto-dismissed
//   history  persisted records, cap 200, ~/.local/state/qsshell/notifications.json
//   dnd / mute / fullscreen suppression, a battery watcher, and notify() to
//   inject synthetic notifications (test button, battery, crash assist WP-09).
//
// Suppression: DND or (fullscreenSuppress && fullscreenActive) hold toasts but
// still record history + bump unread. Muted apps get no toast (still recorded).
// Transient notifications (DND on/off, audio-output changed) always toast and
// are never recorded. fullscreenActive / toastScreen are driven by shell.qml.
QtObject {
    id: mgr

    // ── settings (store-backed) ──────────────────────────────────────────────
    readonly property bool dnd: SettingsBus.get("notifications.dnd", false)
    readonly property bool fullscreenSuppress: SettingsBus.get("notifications.fullscreenSuppress", true)
    readonly property string corner: SettingsBus.get("notifications.corner", "bottom-right")
    readonly property var mutedApps: SettingsBus.get("notifications.muted", [])
    readonly property var batteryThresholds: SettingsBus.get("notifications.batteryThresholds", [20, 10, 5])

    // ── driven by shell.qml ──────────────────────────────────────────────────
    property bool fullscreenActive: false   // focused window ≈ fullscreen (heuristic)
    property string toastScreen: ""          // screen name toasts render on

    // ── live state ───────────────────────────────────────────────────────────
    property var popups: []      // [{id, rec, ref, actions, expire}] — current toasts
    property var history: []     // records, newest first
    property int unread: 0       // since the center was last opened (bell badge)
    property int lastPushedId: 0 // newest toast — only it plays the entrance anim
    property int _seq: 1
    property var _batNotified: ({})

    signal warned(string msg)    // parse/persist issues → toast

    function urgencyName(u) {
        return u === NotificationUrgency.Critical ? "critical"
             : u === NotificationUrgency.Low ? "low" : "normal"
    }
    function _isMuted(app) {
        var m = mgr.mutedApps
        if (!m || !m.length) return false
        for (var i = 0; i < m.length; i++) if (m[i] === app) return true
        return false
    }
    function _progress(n) {
        try { return (n.hints && typeof n.hints.value === "number") ? n.hints.value : -1 }
        catch (e) { return -1 }
    }

    // ── server ───────────────────────────────────────────────────────────────
    property NotificationServer _server: NotificationServer {
        keepOnReload: false
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: function (n) {
            n.tracked = true
            mgr._ingest(n)
        }
    }

    function _ingest(n) {
        var app = n.appName || "Notification"
        var rec = {
            id: mgr._seq++, appName: app, summary: n.summary || "", body: n.body || "",
            image: n.image || "", icon: n.appIcon || "", urgency: mgr.urgencyName(n.urgency),
            time: Date.now(), progress: mgr._progress(n)
        }
        if (!n.transient) { mgr._pushHistory(rec); mgr.unread++ }
        var suppress = mgr.dnd || (mgr.fullscreenSuppress && mgr.fullscreenActive) || mgr._isMuted(app)
        if (!suppress)
            mgr._pushPopup({ id: rec.id, rec: rec, ref: n, actions: n.actions,
                             expire: n.urgency === NotificationUrgency.Critical ? -1 : (n.expireTimeout > 0 ? n.expireTimeout : 5) })
    }

    // Inject a synthetic notification (test button, battery, crash assist, state
    // toasts). opts: {appName, transient, progress, icon}.
    function notify(summary, body, icon, urgency, opts) {
        opts = opts || {}
        var transient = !!opts.transient
        var rec = {
            id: mgr._seq++, appName: opts.appName || "mujō", summary: summary || "", body: body || "",
            image: "", icon: icon || "", urgency: urgency || "normal", time: Date.now(),
            progress: (opts.progress !== undefined ? opts.progress : -1)
        }
        if (!transient) { mgr._pushHistory(rec); mgr.unread++ }
        var suppress = !transient && (mgr.dnd || (mgr.fullscreenSuppress && mgr.fullscreenActive))
        if (!suppress)
            mgr._pushPopup({ id: rec.id, rec: rec, ref: null, actions: opts.actions || null,
                             expire: opts.expire !== undefined ? opts.expire : (transient ? 2.5 : 5) })
    }

    // ── toasts ───────────────────────────────────────────────────────────────
    function _pushPopup(p) {
        var a = mgr.popups.slice()
        a.push(p)
        if (a.length > 4) a = a.slice(a.length - 4)   // cap visible stack
        mgr.lastPushedId = p.id
        mgr.popups = a
    }
    function dismissPopup(id) { mgr.popups = mgr.popups.filter(function (p) { return p.id !== id }) }
    function closePopup(id) {
        var p = mgr.popups.filter(function (x) { return x.id === id })[0]
        if (p && p.ref) p.ref.dismiss()
        mgr.dismissPopup(id)
    }
    function invokeAction(id, action) { if (action) action.invoke(); mgr.dismissPopup(id) }

    // ── history + persistence ────────────────────────────────────────────────
    function _pushHistory(rec) {
        var h = mgr.history.slice()
        h.unshift(rec)
        if (h.length > 200) h = h.slice(0, 200)
        mgr.history = h
        mgr._save()
    }
    function removeHistory(id) { mgr.history = mgr.history.filter(function (r) { return r.id !== id }); mgr._save() }
    function clearHistory() { mgr.history = []; mgr._save() }
    function markSeen() { mgr.unread = 0 }

    // history grouped by app, newest first (for the center)
    function grouped() {
        var groups = [], byApp = ({})
        for (var i = 0; i < mgr.history.length; i++) {
            var r = mgr.history[i], k = r.appName
            if (byApp[k] === undefined) { byApp[k] = groups.length; groups.push({ appName: k, icon: r.icon, items: [] }) }
            groups[byApp[k]].items.push(r)
        }
        return groups
    }

    property Timer _saveTimer: Timer { interval: 500; onTriggered: mgr._flush() }
    function _save() { _saveTimer.restart() }
    function _flush() {
        if (saveProc.running) { _saveTimer.restart(); return }
        saveProc.payload = JSON.stringify({ history: mgr.history })
        saveProc.sent = false
        saveProc.stdinEnabled = true
        saveProc.running = true
    }
    property Process _saveProc: Process {
        id: saveProc
        command: ["mujo", "notify", "write"]
        property string payload: ""
        property bool sent: false
        onRunningChanged: { if (running && !sent) { write(payload); stdinEnabled = false; sent = true } }
    }
    property FileView _histFile: FileView {
        path: (Quickshell.env("HOME") || "/tmp") + "/.local/state/qsshell/notifications.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (saveProc.running) return   // ignore our own write echoing back
            try { var d = JSON.parse(text() || "{}"); if (d && Array.isArray(d.history)) mgr.history = d.history }
            catch (e) { console.warn("Notifications: history parse error", e) }
        }
        onLoadFailed: function (err) {}
    }

    // ── DND + state toasts ───────────────────────────────────────────────────
    function setDnd(v) {
        SettingsBus.set("notifications.dnd", v)
        mgr.notify(v ? "Do Not Disturb on" : "Do Not Disturb off", "",
                   v ? "do_not_disturb_on" : "do_not_disturb_off", "low", { transient: true })
    }
    function toggleDnd() { mgr.setDnd(!mgr.dnd) }

    function muteApp(app, muted) {
        var m = (mgr.mutedApps || []).filter(function (x) { return x !== app })
        if (muted) m.push(app)
        SettingsBus.set("notifications.muted", m)
    }

    // audio-output-changed transient toast
    property string _lastSink: ""
    property Connections _pw: Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            var s = Pipewire.defaultAudioSink
            var name = s ? (s.description || s.name || "") : ""
            if (name && mgr._lastSink && name !== mgr._lastSink)
                mgr.notify("Audio output", name, "speaker", "low", { transient: true })
            mgr._lastSink = name
        }
    }

    // ── battery watcher (30s; inert with no BAT*) ────────────────────────────
    property Timer _batTimer: Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: batProc.running = true
    }
    property Process _batProc: Process {
        id: batProc
        command: ["mujo", "battery"]
        stdout: StdioCollector { onStreamFinished: mgr._onBattery(this.text) }
    }
    function _onBattery(txt) {
        var b
        try { b = JSON.parse(txt) } catch (e) { return }
        if (!b || !b.present) return
        if (b.status === "Charging" || b.status === "Full") { mgr._batNotified = ({}); return }
        var th = mgr.batteryThresholds
        for (var i = 0; i < th.length; i++) {
            if (b.level <= th[i] && !mgr._batNotified[th[i]]) {
                mgr._batNotified[th[i]] = true
                mgr.notify("Battery low", "Battery at " + b.level + "%.", "battery_alert",
                           th[i] <= 10 ? "critical" : "normal")
                break
            }
        }
    }
}
