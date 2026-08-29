pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire

// The shell's notification daemon + state (WP-04). Runs Quickshell's
// NotificationServer in-process (swayosd stays for volume/brightness OSD; every
// libnotify notification routes here). Exposes:
//   popups   live toasts (rendered by NotificationPopup), auto-dismissed;
//            each carries `expire` in SECONDS (-1 = sticky)
//   history  persisted records, cap 200, ~/.local/state/qsshell/notifications.json
//   dnd / mute / fullscreen suppression, sound alerts, battery watcher, and notify()
//   to inject synthetic notifications (test button, battery, crash assist WP-09).
//
// Suppression: DND or (fullscreenSuppress && fullscreenActive) hold toasts but
// still record history + bump unread. Muted apps get no toast (still recorded).
// Transient notifications (DND on/off, audio-output changed) always toast and
// are never recorded. fullscreenActive / toastScreen are driven by shell.qml.
QtObject {
    id: mgr

    // ── settings (store-backed) ──────────────────────────────────────────────
    readonly property bool dnd: SettingsBus.get("notifications.dnd", false)
    readonly property bool fullscreenSuppress: SettingsBus.get("notifications.fullscreenSuppress", false)
    readonly property string corner: SettingsBus.get("notifications.corner", "bottom-right")
    readonly property var mutedApps: SettingsBus.get("notifications.muted", [])
    readonly property var batteryThresholds: SettingsBus.get("notifications.batteryThresholds", [20, 10, 5])
    readonly property bool soundEnabled: SettingsBus.get("notifications.sound", true)
    readonly property string soundUrgency: SettingsBus.get("notifications.soundUrgency", "normal_and_critical") // all | normal_and_critical | critical_only | none
    readonly property int toastTimeout: SettingsBus.get("notifications.toastTimeout", 5)
    readonly property int maxVisible: SettingsBus.get("notifications.maxVisible", 4)

    // ── driven by shell.qml ──────────────────────────────────────────────────
    property bool fullscreenActive: false   // focused window ≈ fullscreen (heuristic)
    property string toastScreen: ""          // screen name toasts render on

    // ── live state ───────────────────────────────────────────────────────────
    property var popups: []      // [{id, rec, ref, actions, defaultAction, expire, hasInlineReply, inlineReplyPlaceholder}]
    property var history: []     // records, newest first
    property int unread: 0       // since the center was last opened (bell badge)
    property int lastPushedId: 0 // newest toast — only it plays the entrance anim
    property int _seq: 1
    property var _batNotified: ({})

    // Clock time for a record, dated once it is no longer today. The toast and
    // the notification centre must agree, so the formatter lives here rather
    // than in either surface.
    function fmtTime(ms) {
        var d = new Date(ms), now = new Date()
        var same = d.toDateString() === now.toDateString()
        var hh = ("0" + d.getHours()).slice(-2), mm = ("0" + d.getMinutes()).slice(-2)
        return same ? (hh + ":" + mm) : ((d.getMonth() + 1) + "/" + d.getDate() + " " + hh + ":" + mm)
    }

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
        try {
            if (!n || !n.hints) return -1
            if (typeof n.hints.value === "number") return n.hints.value
            if (typeof n.hints.percentage === "number") return n.hints.percentage
            return -1
        } catch (e) { return -1 }
    }

    // Resolve system icon path for a notification record
    function resolveIcon(rec) {
        if (!rec) return ""
        var icon = (rec.icon || "").trim()
        // 1. Direct path / URI in icon or image
        if (icon && (icon.indexOf("/") === 0 || icon.indexOf("file://") === 0 || icon.indexOf("image://") === 0 || icon.indexOf("http://") === 0 || icon.indexOf("https://") === 0))
            return icon
        // 2. Themed freedesktop icon lookup
        var candidates = [icon, rec.desktopEntry, (rec.appName || "").toLowerCase(), (rec.appName || "")]
        for (var i = 0; i < candidates.length; i++) {
            var c = candidates[i]
            if (c && typeof c === "string" && Quickshell.hasThemeIcon(c))
                return Quickshell.iconPath(c)
        }
        return ""
    }

    // Resolve rich banner image path or URI (only actual image files/URLs, never theme icon lookups)
    function resolveImage(img) {
        return mgr._isRealImg(img) ? img.trim() : ""
    }

    // ── Sound alerts (PipeWire / system sounds) ──────────────────────────────
    property Process _soundProc: Process {
        id: soundProc
        command: ["pw-play", "/run/current-system/sw/share/sounds/freedesktop/stereo/message.oga"]
    }

    function playAlertSound(urgency, hints) {
        if (!mgr.soundEnabled || mgr.dnd) return
        if (hints && (hints["suppress-sound"] === true || hints["sound-name"] === "silent")) return
        
        var mode = mgr.soundUrgency
        if (mode === "none") return
        if (mode === "critical_only" && urgency !== "critical") return
        if (mode === "normal_and_critical" && urgency === "low") return

        var soundFile = "/run/current-system/sw/share/sounds/freedesktop/stereo/message.oga"
        if (hints && typeof hints["sound-file"] === "string" && hints["sound-file"] !== "") {
            soundFile = hints["sound-file"]
        } else if (urgency === "critical") {
            soundFile = "/run/current-system/sw/share/sounds/freedesktop/stereo/dialog-warning.oga"
        }

        if (soundProc.running) soundProc.kill()
        soundProc.command = ["pw-play", soundFile]
        soundProc.running = true
    }

    // ── server ───────────────────────────────────────────────────────────────
    property NotificationServer _server: NotificationServer {
        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        inlineReplySupported: true
        onNotification: function (n) {
            n.tracked = true
            mgr._ingest(n)
        }
    }

    function _separateActions(actions) {
        var def = null, list = []
        if (!actions) return { defaultAction: null, actions: [] }
        for (var i = 0; i < actions.length; i++) {
            var act = actions[i]
            if (act.identifier === "default" || act.identifier === "0") {
                def = act
            } else {
                list.push(act)
            }
        }
        return { defaultAction: def, actions: list }
    }

    function _isRealImg(str) {
        if (!str || typeof str !== "string") return false
        var s = str.trim()
        if (s.indexOf("image://icon/") === 0 || s.indexOf("image://icon?") === 0) return false
        // Quickshell serves inline `image-data` hints from its own image provider
        // (image://qsimage/<id>/<n>). Those are real pixels, not a themed icon name;
        // dropping them here is what pushed album art into the 22px app-icon slot.
        if (s.indexOf("image://") === 0) return true
        return s.indexOf("/") === 0 || s.indexOf("file://") === 0 || s.indexOf("http://") === 0 || s.indexOf("https://") === 0 || s.indexOf("data:") === 0
    }

    function _ingest(n) {
        var app = n.appName || "Notification"
        var urgencyStr = mgr.urgencyName(n.urgency)
        var acts = mgr._separateActions(n.actions)
        var imgHint = (n.hints && (n.hints["image-path"] || n.hints["image_path"] || n.hints["image-data"] || n.hints["image_data"])) || ""
        var iconHint = (n.hints && (n.hints["icon_data"] || n.hints["app-icon"])) || ""
        
        var richImage = ""
        if (mgr._isRealImg(imgHint)) {
            richImage = (typeof imgHint === "string" ? imgHint.trim() : "")
        } else if (mgr._isRealImg(n.image)) {
            richImage = (typeof n.image === "string" ? n.image.trim() : "")
        }

        var rec = {
            id: mgr._seq++,
            serverNotificationId: n.id,
            appName: app,
            summary: n.summary || "",
            body: n.body || "",
            image: richImage,
            icon: n.appIcon || iconHint || (n.image && !richImage ? n.image : ""),
            desktopEntry: n.desktopEntry || "",
            urgency: urgencyStr,
            time: Date.now(),
            progress: mgr._progress(n),
            hasInlineReply: !!n.hasInlineReply,
            inlineReplyPlaceholder: n.inlineReplyPlaceholder || "Reply…",
            resident: !!n.resident
        }

        // Connect live property changes on tracked notification
        var updateCallback = function () {
            var liveImgHint = (n.hints && (n.hints["image-path"] || n.hints["image_path"] || n.hints["image-data"] || n.hints["image_data"])) || ""
            var liveRichImg = ""
            if (mgr._isRealImg(liveImgHint)) {
                liveRichImg = (typeof liveImgHint === "string" ? liveImgHint.trim() : "")
            } else if (mgr._isRealImg(n.image)) {
                liveRichImg = (typeof n.image === "string" ? n.image.trim() : "")
            }
            rec.summary = n.summary || ""
            rec.body = n.body || ""
            rec.image = liveRichImg
            rec.icon = n.appIcon || (n.image && !liveRichImg ? n.image : "")
            rec.progress = mgr._progress(n)
            mgr._updateLiveRecord(rec)
        }
        try {
            n.summaryChanged.connect(updateCallback)
            n.bodyChanged.connect(updateCallback)
            n.imageChanged.connect(updateCallback)
            n.hintsChanged.connect(updateCallback)
        } catch (e) {}

        if (!n.transient) {
            mgr._pushHistory(rec)
            mgr.unread++
        }

        var suppress = mgr.dnd || (mgr.fullscreenSuppress && mgr.fullscreenActive) || mgr._isMuted(app)
        if (!suppress) {
            var timeout = n.urgency === NotificationUrgency.Critical ? -1
                        // expireTimeout arrives in MILLISECONDS; `expire` is in
                        // seconds everywhere downstream (NotificationPopup
                        // multiplies by 1000). Passing it through raw made every
                        // app-specified timeout 1000x too long — a 5s toast sat
                        // on screen for 83 minutes.
                        : (n.expireTimeout > 0 ? n.expireTimeout / 1000 : mgr.toastTimeout)
            mgr._pushPopup({
                id: rec.id,
                rec: rec,
                ref: n,
                actions: acts.actions,
                defaultAction: acts.defaultAction,
                hasInlineReply: !!n.hasInlineReply,
                inlineReplyPlaceholder: n.inlineReplyPlaceholder || "Reply…",
                expire: timeout
            })
            if (!n.transient) {
                mgr.playAlertSound(urgencyStr, n.hints)
            }
        }
    }

    // In-place live update for active toasts / history
    function _updateLiveRecord(rec) {
        var pList = mgr.popups.slice()
        for (var i = 0; i < pList.length; i++) {
            if (pList[i].id === rec.id) {
                pList[i].rec = Object.assign({}, rec)
                mgr.popups = pList
                break
            }
        }
        var hList = mgr.history.slice()
        for (var j = 0; j < hList.length; j++) {
            if (hList[j].id === rec.id) {
                hList[j] = Object.assign({}, rec)
                mgr.history = hList
                mgr._save()
                break
            }
        }
    }

    // Inject a synthetic notification (test button, battery, crash assist, state toasts).
    // opts: {appName, transient, progress, icon, actions, hasInlineReply, replyCallback, expire}.
    function notify(summary, body, icon, urgency, opts) {
        opts = opts || {}
        var transient = !!opts.transient
        var urgencyStr = urgency || "normal"
        var rec = {
            id: mgr._seq++,
            serverNotificationId: 0,
            appName: opts.appName || "mujō",
            summary: summary || "",
            body: body || "",
            image: opts.image || "",
            icon: icon || "",
            desktopEntry: opts.desktopEntry || "",
            urgency: urgencyStr,
            time: Date.now(),
            progress: (opts.progress !== undefined ? opts.progress : -1),
            hasInlineReply: !!opts.hasInlineReply,
            inlineReplyPlaceholder: opts.inlineReplyPlaceholder || "Reply…",
            resident: false
        }
        if (!transient) {
            mgr._pushHistory(rec)
            mgr.unread++
        }
        var suppress = !transient && (mgr.dnd || (mgr.fullscreenSuppress && mgr.fullscreenActive))
        if (!suppress) {
            var timeout = opts.expire !== undefined ? opts.expire : (transient ? 2.5 : mgr.toastTimeout)
            mgr._pushPopup({
                id: rec.id,
                rec: rec,
                ref: null,
                actions: opts.actions || null,
                defaultAction: opts.defaultAction || null,
                hasInlineReply: !!opts.hasInlineReply,
                inlineReplyPlaceholder: opts.inlineReplyPlaceholder || "Reply…",
                replyCallback: opts.replyCallback || null,
                expire: timeout
            })
            if (!transient) {
                mgr.playAlertSound(urgencyStr, opts.hints || null)
            }
        }
    }

    // ── toasts ───────────────────────────────────────────────────────────────
    function _pushPopup(p) {
        var a = mgr.popups.slice()
        a.push(p)
        var limit = Math.max(1, mgr.maxVisible)
        if (a.length > limit) a = a.slice(a.length - limit)
        mgr.lastPushedId = p.id
        mgr.popups = a
    }
    function dismissPopup(id) { mgr.popups = mgr.popups.filter(function (p) { return p.id !== id }) }
    function closePopup(id) {
        var p = mgr.popups.filter(function (x) { return x.id === id })[0]
        if (p && p.ref) {
            try {
                if (typeof p.ref.dismiss === "function") p.ref.dismiss()
            } catch (e) {
                console.warn("Notifications: failed to dismiss ref", e)
            }
        }
        mgr.dismissPopup(id)
    }
    function invokeAction(id, action) {
        if (action && action.invoke) action.invoke()
        else if (action && typeof action.run === "function") action.run()
        var p = mgr.popups.filter(function (x) { return x.id === id })[0]
        if (!p || !p.rec || !p.rec.resident) mgr.dismissPopup(id)
    }
    function invokeDefault(id) {
        var p = mgr.popups.filter(function (x) { return x.id === id })[0]
        if (p && p.defaultAction) {
            mgr.invokeAction(id, p.defaultAction)
        } else if (p && p.ref && p.actions && p.actions.length > 0) {
            mgr.invokeAction(id, p.actions[0])
        } else {
            mgr.dismissPopup(id)
        }
    }
    function sendReply(id, replyText) {
        var p = mgr.popups.filter(function (x) { return x.id === id })[0]
        if (p) {
            if (p.ref && p.ref.sendInlineReply) {
                p.ref.sendInlineReply(replyText)
            } else if (p.replyCallback && typeof p.replyCallback === "function") {
                p.replyCallback(replyText)
            }
        }
        mgr.dismissPopup(id)
    }

    // Snooze a notification for N minutes
    function snooze(id, minutes) {
        var min = minutes || 5
        var p = mgr.popups.filter(function (x) { return x.id === id })[0]
        var rec = p ? p.rec : mgr.history.filter(function (x) { return x.id === id })[0]
        mgr.dismissPopup(id)
        if (!rec) return

        var timerObj = Qt.createQmlObject('import QtQuick; Timer { interval: ' + (min * 60 * 1000) + '; repeat: false; }', mgr)
        timerObj.triggered.connect(function() {
            mgr.notify(rec.summary, rec.body, rec.icon, rec.urgency, {
                appName: rec.appName,
                image: rec.image,
                desktopEntry: rec.desktopEntry
            })
            timerObj.destroy()
        })
        timerObj.start()
    }

    // ── history + persistence ────────────────────────────────────────────────
    function _pushHistory(rec) {
        var h = mgr.history.slice()
        h.unshift(rec)
        if (h.length > 200) h = h.slice(0, 200)
        mgr.history = h
        mgr._save()
    }
    function removeHistory(id) {
        mgr.history = mgr.history.filter(function (r) { return r.id !== id })
        mgr._save()
    }
    function clearAppHistory(appName) {
        mgr.history = mgr.history.filter(function (r) { return r.appName !== appName })
        mgr._save()
    }
    function clearHistory() {
        mgr.history = []
        mgr._save()
    }
    function markSeen() { mgr.unread = 0 }

    // history grouped by app, newest first (for the center)
    function grouped() {
        var groups = [], byApp = ({})
        for (var i = 0; i < mgr.history.length; i++) {
            var r = mgr.history[i], k = r.appName || "Notification"
            if (byApp[k] === undefined) {
                byApp[k] = groups.length
                groups.push({ appName: k, icon: r.icon, desktopEntry: r.desktopEntry, items: [] })
            }
            groups[byApp[k]].items.push(r)
        }
        return groups
    }

    // List of recent distinct application names
    function getRecentApps() {
        var map = ({}), list = []
        for (var i = 0; i < mgr.history.length; i++) {
            var name = mgr.history[i].appName
            if (name && !map[name]) {
                map[name] = true
                list.push(name)
            }
        }
        var m = mgr.mutedApps || []
        for (var j = 0; j < m.length; j++) {
            if (m[j] && !map[m[j]]) {
                map[m[j]] = true
                list.push(m[j])
            }
        }
        return list
    }

    property Timer _saveTimer: Timer { id: saveTimer; interval: 500; onTriggered: mgr._flush() }
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
            if (saveProc.running || saveTimer.running) return
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

    // SettingsBus warning listener
    property Connections _settingsWarn: Connections {
        target: SettingsBus
        function onWarning(msg) {
            mgr.notify("Settings", msg, "warning", "critical", { appName: "mujō" })
        }
    }

    // ── battery watcher (30s; inert with no BAT*) ────────────────────────────
    property Timer _batTimer: Timer {
        id: batTimer
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
        if (!b || !b.present) { batTimer.stop(); return }
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

