import QtQuick
import Quickshell
import Quickshell.Io

// Idle rules engine (WP-13). Owns a single respawned `swayidle -w` process built
// from the ordered SettingsBus `idle.rules` list. Rebuilt whenever the rules or
// the master toggle change; respawned if swayidle ever dies. swayidle runs each
// command through `sh -c`, so per-rule inhibit guards are shell strings that
// short-circuit the action when audio is playing / on AC.
//
// ponytail: swayidle only re-fires a timeout after the next activity→idle cycle,
// so a guard that inhibits at the threshold won't retry until you move and idle
// again — accepted; a systemd-inhibitor loop is the upgrade if it bites.
Scope {
    id: root

    readonly property bool enabled: SettingsBus.get("idle.enabled", true)
    readonly property var rules: SettingsBus.get("idle.rules", [])

    // WP-14: drive the native session lock through its IPC (same stable path the
    // niri keybind uses). swayidle runs as a separate process, so it can't call
    // the Lock singleton directly the way Session does.
    readonly property string _lockCmd: "qs -p /etc/xdg/quickshell/bar/shell.qml ipc call lock lock"

    // action id → command run on timeout / on resume ("" = no resume hook).
    function _on(r) {
        switch (r.action) {
        case "dim": return "brightnessctl -s set 20%"
        case "screenOff": return "niri msg action power-off-monitors"
        case "lock": return root._lockCmd
        case "suspend": return "systemctl suspend"
        case "hibernate": return "systemctl hibernate"
        case "effects": return "mujo settings set effects.idleActive true --json"
        case "custom": return r.command || "true"
        }
        return "true"
    }
    function _resume(r) {
        switch (r.action) {
        case "dim": return "brightnessctl -r"
        case "screenOff": return "niri msg action power-on-monitors"
        case "effects": return "mujo settings set effects.idleActive false --json"
        case "custom": return r.returnAction || ""
        }
        return ""
    }
    function _guard(r, cmd) {
        var g = []
        if (r.inhibitWhenAudio) g.push("mujo idle-guard audio")
        if (r.inhibitWhenCharging) g.push("mujo idle-guard charging")
        if (!g.length) return cmd
        return "{ " + g.join(" || ") + "; } && exit 0; " + cmd
    }

    readonly property var cmdline: {
        if (!enabled || !rules || !rules.length) return []
        var a = ["swayidle", "-w"]
        for (var i = 0; i < rules.length; i++) {
            var r = rules[i]
            var t = Math.max(1, parseInt(r.timeoutSec) || 0)
            if (!t) continue
            a.push("timeout", String(t), _guard(r, _on(r)))
            var res = _resume(r)
            if (res) a.push("resume", res)
        }
        // Always lock before the machine actually sleeps.
        a.push("before-sleep", root._lockCmd)
        return a
    }

    property bool _pendingReload: false
    onCmdlineChanged: debounce.restart()
    Component.onCompleted: debounce.restart()

    function _start() {
        if (root.enabled && root.cmdline.length) {
            proc.command = root.cmdline
            proc.running = true
        }
    }
    // Reload = kill the running instance and restart from onExited, so an
    // intentional restart is never mistaken for a crash (which schedules respawn).
    function reload() {
        if (proc.running) { root._pendingReload = true; proc.running = false }
        else root._start()
    }

    Process {
        id: proc
        onExited: {
            if (root._pendingReload) { root._pendingReload = false; root._start() }
            else if (root.enabled && root.cmdline.length) respawn.restart()  // crash
        }
    }
    Timer { id: debounce; interval: 300; onTriggered: root.reload() }   // coalesce rule bursts
    Timer { id: respawn; interval: 1000; onTriggered: root.reload() }
}
